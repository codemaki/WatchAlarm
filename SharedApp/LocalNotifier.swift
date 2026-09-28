import Foundation
import UserNotifications

/// UNUserNotificationCenter 래퍼 (아이폰 / 워치 공용)
enum LocalNotifier {
    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// 즉시 로컬 알림 표시. 실패 시 사유 반환, 성공 시 nil.
    static func post(_ payload: AlertPayload) async -> String? {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status != .denied, status != .notDetermined else {
            return "알림 권한 없음(\(status.rawValue))"
        }

        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.body
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        // 같은 id 는 같은 알림으로 취급 → 중복 표시 방지
        let request = UNNotificationRequest(identifier: payload.id, content: content, trigger: nil)
        do {
            try await center.add(request)
            return nil
        } catch {
            return "알림 등록 실패: \(error.localizedDescription)"
        }
    }
}

/// 앱이 포그라운드일 때도 배너를 보여준다.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationPresenter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
