import Foundation

/// 임계값 / Webhook URL 을 WCSession applicationContext 로 양방향 동기화한다.
/// 충돌 시 updatedAt 이 더 최신인 쪽이 이긴다.
enum SettingsSync {
    struct Incoming: Sendable {
        let threshold: Int
        let webhookURL: String
        let updatedAt: Date
    }

    static func makeContext() -> [String: Any] {
        [
            MessageKey.threshold: SharedDefaults.threshold,
            MessageKey.webhookURL: SharedDefaults.webhookURL,
            MessageKey.updatedAt: SharedDefaults.settingsUpdatedAt.timeIntervalSince1970,
        ]
    }

    static func parse(_ context: [String: Any]) -> Incoming? {
        guard let threshold = context[MessageKey.threshold] as? Int,
              let updatedAt = context[MessageKey.updatedAt] as? Double
        else { return nil }
        return Incoming(
            threshold: threshold,
            webhookURL: context[MessageKey.webhookURL] as? String ?? "",
            updatedAt: Date(timeIntervalSince1970: updatedAt)
        )
    }

    /// 받은 설정이 더 최신이면 저장하고 true 반환
    static func apply(_ incoming: Incoming) -> Bool {
        guard incoming.updatedAt > SharedDefaults.settingsUpdatedAt else { return false }
        SharedDefaults.threshold = incoming.threshold
        SharedDefaults.webhookURL = incoming.webhookURL
        SharedDefaults.settingsUpdatedAt = incoming.updatedAt
        return true
    }
}
