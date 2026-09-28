import Foundation

/// WKInterfaceDevice.batteryState 를 기기 독립적으로 표현 (위젯/아이폰에서도 사용)
enum ChargeState: String, Codable, Sendable {
    case charging
    case full
    case unplugged
    case unknown

    /// 충전기에 연결된 상태 (.charging 또는 .full)
    var isOnCharger: Bool { self == .charging || self == .full }

    var label: String {
        switch self {
        case .charging: "충전 중"
        case .full: "완충"
        case .unplugged: "분리됨"
        case .unknown: "알 수 없음"
        }
    }
}
