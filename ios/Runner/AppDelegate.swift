import Flutter
import CarPlay
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  lazy var flutterEngine = FlutterEngine(name: "shared_engine")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: self.flutterEngine)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Handle CarPlay scenes - let flutter_carplay package handle them
        if scene is CPTemplateApplicationScene {
            return
        }
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let controller = FlutterViewController(engine: appDelegate.flutterEngine, nibName: nil, bundle: nil)
        
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = controller
        self.window = window
        window.makeKeyAndVisible()
    }
}
