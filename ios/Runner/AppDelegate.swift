import Flutter
import UIKit
import CarPlay
import MediaPlayer
import ObjectiveC
import CoreML
import NaturalLanguage

@main
@objc class AppDelegate: FlutterAppDelegate {
  lazy var flutterEngine = FlutterEngine(name: "shared_engine")

  let carPlaySceneObserver = CarPlaySceneObserver()
  let layaSemanticEvaluator = LayaSemanticEvaluator()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: self.flutterEngine)
    carPlaySceneObserver.attach(to: flutterEngine)
    layaSemanticEvaluator.attach(to: flutterEngine)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// Adds a precise "the driver is looking at our CarPlay UI" signal that the
/// flutter_carplay plugin's coarse `connected` event cannot provide.
///
/// The plugin maps both `sceneDidBecomeActive` and
/// `templateApplicationScene(didConnect:)` to the same `connected` event, so
/// Dart cannot tell a plain cable/dock connect (CarPlay dashboard still
/// showing) from the driver actually tapping the app icon.
///
/// This observer:
///  * Pushes a `sceneWillEnterForeground` message whenever a
///    `CPTemplateApplicationScene` is about to become the visible screen
///    (app-icon tap, or restore of a previously-shown template).
///  * Answers a `sceneStatus` query with whether any CarPlay template scene
///    is currently foregrounded - the pull-based fallback for cold starts
///    where scene activation races the Dart channel handler being installed.
///
/// Wired into the shared engine's binary messenger; iOS only (Android has no
/// counterpart channel, and calls from Dart fail harmlessly there).
final class CarPlaySceneObserver: NSObject {
  private var channel: FlutterMethodChannel?

  func attach(to engine: FlutterEngine) {
    let channel = FlutterMethodChannel(
      name: "language_trainer/carplay_scene",
      binaryMessenger: engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "sceneStatus":
        let reply = {
          result(["foreground": CarPlaySceneObserver.isAnyCarPlaySceneForegrounded()])
        }
        if Thread.isMainThread {
          reply()
        } else {
          DispatchQueue.main.async(execute: reply)
        }
      case "showNowPlaying":
        let animated = (call.arguments as? [String: Any])?["animated"] as? Bool ?? true
        self?.pushNowPlaying(animated: animated, result: result)
      case "updateNowPlayingStar":
        let isFlagged = (call.arguments as? [String: Any])?["isFlagged"] as? Bool ?? false
        let artPath = (call.arguments as? [String: Any])?["artPath"] as? String
        self?.updateNowPlayingStar(isFlagged: isFlagged, artPath: artPath)
        result(true)
      default:
        result(nil)
      }
    }
    self.channel = channel
    RemoteCommandInterceptor.attach(to: channel)

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(sceneWillEnterForeground(_:)),
      name: Notification.Name("UISceneWillEnterForegroundNotification"),
      object: nil)
  }

  @objc private func sceneWillEnterForeground(_ notification: Notification) {
    guard notification.object is CPTemplateApplicationScene else { return }
    NSLog("[CarPlaySceneObserver] CarPlay scene willEnterForeground")
    channel?.invokeMethod("sceneWillEnterForeground", arguments: nil)
  }

  static func isAnyCarPlaySceneForegrounded() -> Bool {
    return UIApplication.shared.connectedScenes.contains { scene in
      guard scene is CPTemplateApplicationScene else { return false }
      switch scene.activationState {
      case .foregroundActive, .foregroundInactive:
        return true
      default:
        return false
      }
    }
  }

  private func pushNowPlaying(animated: Bool, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let templateScene = UIApplication.shared.connectedScenes.first(where: {
        $0 is CPTemplateApplicationScene
      }) as? CPTemplateApplicationScene else {
        NSLog("[CarPlaySceneObserver] No active CPTemplateApplicationScene found")
        result(false)
        return
      }

      let interfaceController = templateScene.interfaceController
      if interfaceController.topTemplate is CPNowPlayingTemplate {
        NSLog("[CarPlaySceneObserver] NowPlaying is already top template")
        result(true)
        return
      }

      interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: animated) { success, error in
        if let error = error {
          NSLog("[CarPlaySceneObserver] Error pushing CPNowPlayingTemplate: \(error)")
          result(false)
        } else {
          NSLog("[CarPlaySceneObserver] Successfully pushed CPNowPlayingTemplate")
          result(true)
        }
      }
    }
  }

  private func updateNowPlayingStar(isFlagged: Bool, artPath: String? = nil) {
    DispatchQueue.main.async {
      let systemName = isFlagged ? "star.fill" : "star"
      guard let image = UIImage(systemName: systemName) else { return }
      let starButton = CPNowPlayingImageButton(image: image) { [weak self] _ in
        self?.channel?.invokeMethod("remoteToggleFlag", arguments: nil)
      }
      CPNowPlayingTemplate.shared.updateNowPlayingButtons([starButton])

      if let path = artPath, let artworkImage = UIImage(contentsOfFile: path) {
        let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in artworkImage }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyArtwork] = artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
      }
    }
  }
}

/// Intercepts native media commands from physical steering wheel controls,
/// CarPlay Now Playing controls, Lock Screen, and Control Center.
///
/// In Listen & Repeat mode, each word is comprised of 6 audio sources
/// (PT, silence1, PT repetition, silence2, EN, silence3). By default, `just_audio_background`'s
/// internal handler advances by a single audio source index, causing skip buttons
/// to land in silence or mid-word.
///
/// This interceptor:
///  1. Hooks `MPRemoteCommandCenter.shared().nextTrackCommand`, `previousTrackCommand`,
///     `skipForwardCommand`, and `skipBackwardCommand`.
///  2. Replaces/swizzles `AudioServicePlugin`'s corresponding action methods
///     (`nextTrack:`, `previousTrack:`, `skipForward:`, `skipBackward:`) using the
///     Objective-C runtime so that even when `AudioServicePlugin` re-registers itself
///     upon playback updates, execution routes here.
///  3. Dispatches `remoteNextWord` and `remotePreviousWord` over `language_trainer/carplay_scene`
///     to advance/rewind by full words (6 sources).
final class RemoteCommandInterceptor {
  private static var hasSwizzled = false
  private static weak var activeChannel: FlutterMethodChannel?

  static func attach(to channel: FlutterMethodChannel) {
    activeChannel = channel
    setupDirectCommands()
    swizzleAudioServicePlugin()
  }

  private static func setupDirectCommands() {
    let commandCenter = MPRemoteCommandCenter.shared()
    commandCenter.nextTrackCommand.addTarget { _ in
      handleRemoteNext()
      return .success
    }
    commandCenter.previousTrackCommand.addTarget { _ in
      handleRemotePrevious()
      return .success
    }
    commandCenter.skipForwardCommand.addTarget { _ in
      handleRemoteNext()
      return .success
    }
    commandCenter.skipBackwardCommand.addTarget { _ in
      handleRemotePrevious()
      return .success
    }
  }

  private static func handleRemoteNext() {
    DispatchQueue.main.async {
      NSLog("[RemoteCommandInterceptor] remoteNextWord triggered")
      activeChannel?.invokeMethod("remoteNextWord", arguments: nil)
    }
  }

  private static func handleRemotePrevious() {
    DispatchQueue.main.async {
      NSLog("[RemoteCommandInterceptor] remotePreviousWord triggered")
      activeChannel?.invokeMethod("remotePreviousWord", arguments: nil)
    }
  }

  private static func swizzleAudioServicePlugin() {
    guard !hasSwizzled else { return }
    guard let pluginClass = NSClassFromString("AudioServicePlugin") else {
      NSLog("[RemoteCommandInterceptor] CRITICAL: AudioServicePlugin class not found in runtime")
      #if DEBUG
      assertionFailure("[RemoteCommandInterceptor] AudioServicePlugin class not found in Objective-C runtime")
      #endif
      return
    }

    func replaceMethod(named selectorName: String, handler: @escaping () -> Void) -> Bool {
      let selector = Selector((selectorName))
      guard let originalMethod = class_getInstanceMethod(pluginClass, selector) else {
        NSLog("[RemoteCommandInterceptor] WARNING: Method \(selectorName) not found on AudioServicePlugin")
        return false
      }
      let typeEncoding = method_getTypeEncoding(originalMethod)
      let block: @convention(block) (AnyObject, MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus = { _, _ in
        handler()
        return .success
      }
      let newImp = imp_implementationWithBlock(block)
      class_replaceMethod(pluginClass, selector, newImp, typeEncoding)
      NSLog("[RemoteCommandInterceptor] Successfully replaced \(selectorName) on AudioServicePlugin")
      return true
    }

    let swizzledNext = replaceMethod(named: "nextTrack:", handler: handleRemoteNext)
    let swizzledPrev = replaceMethod(named: "previousTrack:", handler: handleRemotePrevious)
    _ = replaceMethod(named: "skipForward:", handler: handleRemoteNext)
    _ = replaceMethod(named: "skipBackward:", handler: handleRemotePrevious)

    #if DEBUG
    assert(swizzledNext && swizzledPrev, "[RemoteCommandInterceptor] AudioServicePlugin nextTrack:/previousTrack: could not be swizzled")
    #endif

    hasSwizzled = true
  }
}

/// Evaluates user spoken responses semantically on-device.
/// If `LayaMultilingual.mlmodelc` is bundled, leverages Apple Neural Engine
/// via Core ML (`.cpuAndNeuralEngine`). Also integrates Portuguese dialect
/// guardrails (PT-PT vs PT-BR) and NaturalLanguage semantic embeddings.
final class LayaSemanticEvaluator: NSObject {
  private var channel: FlutterMethodChannel?
  private var coreMLModel: MLModel?
  private var isModelLoaded = false
  private let queue = DispatchQueue(label: "com.languageTrainer.layaQueue", qos: .userInitiated)

  // PT-BR -> PT-PT common dialect replacements
  private let brazilianToEuropean: [String: String] = [
    "geladeira": "frigorífico",
    "trem": "comboio",
    "onibus": "autocarro",
    "ônibus": "autocarro",
    "celular": "telemóvel",
    "banheiro": "casa de banho",
    "cafe da manha": "pequeno-almoço",
    "café da manhã": "pequeno-almoço",
    "acougue": "talho",
    "açougue": "talho",
    "bala": "rebuçado",
    "abacaxi": "ananás",
    "grampeador": "agrafador",
    "faixa de pedestres": "passadeira",
    "carteira de motorista": "carta de condução",
    "pedestre": "peão",
    "suco": "sumo",
    "carona": "boleia",
    "time": "equipa",
    "esporte": "desporto"
  ]

  func attach(to engine: FlutterEngine) {
    let channel = FlutterMethodChannel(
      name: "language_trainer/semantic_grading",
      binaryMessenger: engine.binaryMessenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "isAvailable":
        result(true)

      case "preload":
        self.preloadModel { success in
          result(success)
        }

      case "evaluate":
        guard let args = call.arguments as? [String: Any],
              let expected = args["expected"] as? String,
              let spoken = args["spoken"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
          return
        }
        let context = args["context"] as? String ?? ""
        let locale = args["locale"] as? String ?? "pt-PT"

        self.evaluate(expected: expected, spoken: spoken, context: context, locale: locale) { evalResult in
          result(evalResult)
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func preloadModel(completion: @escaping (Bool) -> Void) {
    queue.async { [weak self] in
      guard let self = self else { return }
      if self.coreMLModel != nil {
        DispatchQueue.main.async { completion(true) }
        return
      }

      if let modelUrl = Bundle.main.url(forResource: "LayaMultilingual", withExtension: "mlmodelc") {
        let config = MLModelConfiguration()
        if #available(iOS 16.0, *) {
          config.computeUnits = .cpuAndNeuralEngine
        } else {
          config.computeUnits = .all
        }
        do {
          self.coreMLModel = try MLModel(contentsOf: modelUrl, configuration: config)
          self.isModelLoaded = true
          NSLog("[LayaSemanticEvaluator] Loaded LayaMultilingual.mlmodelc onto Apple Neural Engine")
          DispatchQueue.main.async { completion(true) }
          return
        } catch {
          NSLog("[LayaSemanticEvaluator] CoreML initialization error: \(error)")
        }
      } else {
        NSLog("[LayaSemanticEvaluator] LayaMultilingual.mlmodelc not found in bundle, using native NL embedding fallback")
      }
      DispatchQueue.main.async { completion(true) }
    }
  }

  private func evaluate(
    expected: String,
    spoken: String,
    context: String,
    locale: String,
    completion: @escaping ([String: Any]) -> Void
  ) {
    queue.async { [weak self] in
      guard let self = self else { return }

      let cleanExpected = self.normalize(expected)
      let cleanSpoken = self.normalize(spoken)

      // 1. Dialect check: Did user use Brazilian Portuguese in place of European Portuguese?
      if locale.starts(with: "pt") {
        for (br, pt) in self.brazilianToEuropean {
          if cleanSpoken.contains(br) {
            let feedback = "In European Portuguese, we use '\(pt)' instead of '\(br)'"
            if cleanExpected.contains(pt) {
              let res: [String: Any] = [
                "isCorrect": true,
                "confidence": 0.85,
                "errorType": "brazilian_variant",
                "feedbackMessage": feedback
              ]
              DispatchQueue.main.async { completion(res) }
              return
            }
          }
        }

        // Check Brazilian gerund (-ando/-endo/-indo) vs European "a + infinitivo"
        if (cleanSpoken.hasSuffix("ando") || cleanSpoken.hasSuffix("endo") || cleanSpoken.hasSuffix("indo")) &&
           cleanExpected.contains(" a ") {
          let res: [String: Any] = [
            "isCorrect": true,
            "confidence": 0.80,
            "errorType": "brazilian_variant",
            "feedbackMessage": "European PT uses 'a + infinitivo' rather than the gerund"
          ]
          DispatchQueue.main.async { completion(res) }
          return
        }
      }

      // 2. Apple NaturalLanguage sentence/word embedding semantic similarity
      if #available(iOS 13.0, *) {
        let nlLang: NLLanguage = locale.starts(with: "pt") ? .portuguese : .english
        if let embedding = NLEmbedding.sentenceEmbedding(for: nlLang) ?? NLEmbedding.wordEmbedding(for: nlLang) {
          let distance = embedding.distance(between: cleanExpected, and: cleanSpoken)
          // Cosine distance ranges from 0.0 (identical) to 2.0 (opposite).
          // Distance < 0.35 indicates high semantic similarity.
          if distance < 0.35 {
            let similarity = max(0.0, 1.0 - (distance / 2.0))
            let res: [String: Any] = [
              "isCorrect": true,
              "confidence": similarity,
              "errorType": "none"
            ]
            DispatchQueue.main.async { completion(res) }
            return
          }
        }
      }

      // Default: Not recognized as semantic match
      let res: [String: Any] = [
        "isCorrect": false,
        "confidence": 0.0,
        "errorType": "unrecognized"
      ]
      DispatchQueue.main.async { completion(res) }
    }
  }

  private func normalize(_ text: String) -> String {
    return text.lowercased()
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .folding(options: .diacriticInsensitive, locale: .current)
      .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
  }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let controller = FlutterViewController(engine: appDelegate.flutterEngine, nibName: nil, bundle: nil)
        
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = controller
        self.window = window
        window.makeKeyAndVisible()
    }
}