import SwiftUI
import UserNotifications
import WatchKit

@main
struct WatchAlarmWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
        // scheduleBackgroundRefresh 로 예약한 백그라운드 refresh.
        // 클로저가 반환되면 SwiftUI 가 task 를 완료 처리한다.
        // (watchOS 27 SDK 에서 deprecated 되었지만, 최소 지원 버전 watchOS 26 에서 동작이 확인된 형태를 사용)
        .backgroundTask(.appRefresh) { _ in
            await WatchModel.shared.performCheck(trigger: .backgroundRefresh)
        }
        // 아이폰에서 설정(applicationContext)이 도착해 백그라운드로 깨어난 경우
        .backgroundTask(.watchConnectivity) {
            await WatchSessionManager.shared.waitForPendingContent()
        }
    }
}

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
        WatchSessionManager.shared.activate()
    }
}
