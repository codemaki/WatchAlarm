import Foundation

/// 워치 → 아이폰으로 보내는 알림 내용
struct AlertPayload: Sendable {
    let id: String
    let level: Int
    let threshold: Int
    let state: ChargeState
    let timestamp: Date
    let isTest: Bool

    init(level: Int, threshold: Int, state: ChargeState, isTest: Bool = false) {
        self.id = UUID().uuidString
        self.level = level
        self.threshold = threshold
        self.state = state
        self.timestamp = Date()
        self.isTest = isTest
    }

    init?(dictionary: [String: Any]) {
        guard dictionary[MessageKey.type] as? String == MessageType.alert,
              let id = dictionary[MessageKey.id] as? String,
              let level = dictionary[MessageKey.level] as? Int,
              let threshold = dictionary[MessageKey.threshold] as? Int,
              let time = dictionary[MessageKey.timestamp] as? Double
        else { return nil }
        self.id = id
        self.level = level
        self.threshold = threshold
        self.state = ChargeState(rawValue: dictionary[MessageKey.state] as? String ?? "") ?? .unknown
        self.timestamp = Date(timeIntervalSince1970: time)
        self.isTest = dictionary[MessageKey.isTest] as? Bool ?? false
    }

    var dictionary: [String: Any] {
        [
            MessageKey.type: MessageType.alert,
            MessageKey.id: id,
            MessageKey.level: level,
            MessageKey.threshold: threshold,
            MessageKey.state: state.rawValue,
            MessageKey.timestamp: timestamp.timeIntervalSince1970,
            MessageKey.isTest: isTest,
        ]
    }

    var title: String {
        isTest ? "[테스트] Apple Watch 충전 알림" : "Apple Watch 충전 \(threshold)% 도달"
    }

    var body: String {
        "배터리 \(level)% (설정 \(threshold)%, \(state.label)) — 충전기를 분리하세요."
    }
}
