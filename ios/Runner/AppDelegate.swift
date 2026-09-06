import Flutter
import UIKit
import CarPlay

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