import Foundation

enum AppConstants {
    static let appGroupID = "group.com.gonmmu.galarm"
    static let defaultThreshold = 80
    static let thresholdRange = 50...100
    /// 배터리가 (임계값 - resetMargin) 미만으로 내려가면 알림 상태를 초기화한다.
    static let resetMargin = 5
    static let maxLogEntries = 200
    static let defaultRefreshInterval: TimeInterval = 15 * 60
    static let widgetKind = "BatteryComplication"
    static let refreshUserInfo = "batteryCheck"
}

/// WCSession 메시지/컨텍스트 딕셔너리 키
enum MessageKey {
    static let type = "type"
    static let id = "id"
    static let level = "level"
    static let threshold = "threshold"
    static let state = "state"
    static let timestamp = "timestamp"
    static let isTest = "isTest"
    static let webhookURL = "webhookURL"
    static let updatedAt = "updatedAt"
    static let ok = "ok"
    static let error = "error"
}

enum MessageType {
    static let alert = "alert"
}
