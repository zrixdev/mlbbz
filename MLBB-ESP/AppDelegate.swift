import UIKit
import SwiftUI

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let contentView = ContentView()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: contentView)
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        ScreenCaptureService.shared.stop()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        ScreenCaptureService.shared.start()
    }
}
