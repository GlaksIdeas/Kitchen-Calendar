import SwiftUI
import UIKit

/// Kitchen Calendar: the iPad shows the control panel, and a TV plugged in
/// through the Lightning Digital AV Adapter shows the calendar display.
@main
struct KitchenCalendarApp: App {
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            ControlPanelView()
                .environmentObject(model)
                .environmentObject(model.calendar)
                .environmentObject(model.weather)
                .environmentObject(model.home)
                .task { await model.start() }
        }
    }
}

/// Routes an external display (the TV) to its own scene instead of mirroring the iPad.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if connectingSceneSession.role.rawValue.contains("ExternalDisplay") {
        let config = UISceneConfiguration(name: "TV Display", sessionRole: connectingSceneSession.role)
            config.delegateClass = ExternalDisplaySceneDelegate.self
            return config
        }
        return UISceneConfiguration(name: nil,sessionRole: connectingSceneSession.role)
    }
}

/// Puts the calendar display on the TV whenever it is plugged in.
final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let model = AppModel.shared
        let root = TVDisplayView()
            .environmentObject(model)
            .environmentObject(model.calendar)
            .environmentObject(model.weather)
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: root)
        window.isHidden = false
        self.window = window
        model.tvConnected = true
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        AppModel.shared.tvConnected = false
    }
}
