import Foundation

/// 같은 기기 안의 앱 ↔ 위젯이 공유하는 App Group UserDefaults.
/// App Group은 기기 간 공유가 되지 않으므로 워치 ↔ 아이폰 동기화는 WCSession(SettingsSync)으로 한다.
enum SharedDefaults {
    /// UserDefaults 는 스레드 안전하지만 SDK 상 Sendable 로 표시되어 있지 않다.
    nonisolated(unsafe) static let store: UserDefaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard

    private enum Key {
        static let threshold = "threshold"
        static let settingsUpdatedAt = "settingsUpdatedAt"
        static let webhookURL = "webhookURL"
        static let latestLevel = "latestLevel"
        static let latestState = "latestState"
        static let latestDate = "latestDate"
        static let alerted = "alertedForCurrentCharge"
        static let samples = "chargeSamples"
        static let nextRefreshDate = "nextRefreshDate"
        static let logs = "logs"
        static let handledAlertIDs = "handledAlertIDs"
    }

    // MARK: 설정 (두 기기 간 동기화 대상)

    static func clampThreshold(_ value: Int) -> Int {
        min(max(value, AppConstants.thresholdRange.lowerBound), AppConstants.thresholdRange.upperBound)
    }

    static var threshold: Int {
        get {
            let value = store.integer(forKey: Key.threshold)
            return value == 0 ? AppConstants.defaultThreshold : clampThreshold(value)
        }
        set { store.set(clampThreshold(newValue), forKey: Key.threshold) }
    }

    static var webhookURL: String {
        get { store.string(forKey: Key.webhookURL) ?? "" }
        set { store.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.webhookURL) }
    }

    /// 설정이 마지막으로 바뀐 시각. 두 기기 중 더 최신 값이 이긴다.
    static var settingsUpdatedAt: Date {
        get { store.object(forKey: Key.settingsUpdatedAt) as? Date ?? .distantPast }
        set { store.set(newValue, forKey: Key.settingsUpdatedAt) }
    }

    // MARK: 워치 배터리 최신값 (워치 앱 → 컴플리케이션)

    static var latestLevel: Int? {
        get { store.object(forKey: Key.latestLevel) as? Int }
        set { store.set(newValue, forKey: Key.latestLevel) }
    }

    static var latestState: ChargeState {
        get { ChargeState(rawValue: store.string(forKey: Key.latestState) ?? "") ?? .unknown }
        set { store.set(newValue.rawValue, forKey: Key.latestState) }
    }

    static var latestDate: Date? {
        get { store.object(forKey: Key.latestDate) as? Date }
        set { store.set(newValue, forKey: Key.latestDate) }
    }

    // MARK: 알림 상태 (워치)

    /// 이번 충전에서 이미 알림을 보냈는지
    static var alertedForCurrentCharge: Bool {
        get { store.bool(forKey: Key.alerted) }
        set { store.set(newValue, forKey: Key.alerted) }
    }

    static var chargeSamples: [BatterySample] {
        get { decode([BatterySample].self, forKey: Key.samples) ?? [] }
        set { encode(newValue, forKey: Key.samples) }
    }

    static var nextRefreshDate: Date? {
        get { store.object(forKey: Key.nextRefreshDate) as? Date }
        set { store.set(newValue, forKey: Key.nextRefreshDate) }
    }

    // MARK: 로그

    static var logs: [LogEntry] {
        get { decode([LogEntry].self, forKey: Key.logs) ?? [] }
        set { encode(newValue, forKey: Key.logs) }
    }

    // MARK: 아이폰 중복 알림 방지

    static var handledAlertIDs: [String] {
        get { store.stringArray(forKey: Key.handledAlertIDs) ?? [] }
        set { store.set(Array(newValue.suffix(50)), forKey: Key.handledAlertIDs) }
    }

    // MARK: helpers

    private static func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func encode<T: Encodable>(_ value: T, forKey key: String) {
        store.set(try? JSONEncoder().encode(value), forKey: key)
    }
}

/// 충전 속도 추정용 (시각, 배터리%) 샘플
struct BatterySample: Codable, Sendable {
    let date: Date
    let level: Int
}
