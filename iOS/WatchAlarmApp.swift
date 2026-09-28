import SwiftUI
import UIKit
import UserNotifications

@main
struct WatchAlarmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// 워치의 sendMessage 로 백그라운드 실행될 때도 호출되므로 여기서 WCSession 을 활성화한다.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
        PhoneSessionManager.shared.activate()
        return true
    }
}
