import Flutter
import UIKit
import CarPlay
import MediaPlayer
import ObjectiveC

@main
@objc class AppDelegate: FlutterAppDelegate {
  lazy var flutterEngine = FlutterEngine(name: "shared_engine")

  let carPlaySceneObserver = CarPlaySceneObserver()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: self.flutterEngine)
    carPlaySceneObserver.attach(to: flutterEngine)
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
    channel.setMethodCallHandler { call, result in
      guard call.method == "sceneStatus" else {
        result(nil)
        return
      }
      let reply = {
        result(["foreground": CarPlaySceneObserver.isAnyCarPlaySceneForegrounded()])
      }
      if Thread.isMainThread {
        reply()
      } else {
        DispatchQueue.main.async(execute: reply)
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
}

/// Intercepts native media commands from physical steering wheel controls,
/// CarPlay Now Playing controls, Lock Screen, and Control Center.
///
/// In Listen & Repeat mode, each word is comprised of 5 audio sources
/// (PT, silence1, silence2, EN, silence3). By default, `just_audio_background`'s
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
///     to advance/rewind by full words (5 sources).
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