import Foundation
import WatchKit

struct BatteryReading: Sendable {
    /// 0...100, 읽을 수 없으면 nil (시뮬레이터 등에서 batteryLevel == -1)
    let level: Int?
    let state: ChargeState
    let date: Date
}

@MainActor
enum BatteryReader {
    static func read() -> BatteryReading {
        let device = WKInterfaceDevice.current()
        device.isBatteryMonitoringEnabled = true

        let raw = device.batteryLevel
        let level: Int? = raw < 0 ? nil : Int((raw * 100).rounded())

        let state: ChargeState = switch device.batteryState {
        case .charging: .charging
        case .full: .full
        case .unplugged: .unplugged
        case .unknown: .unknown
        @unknown default: .unknown
        }
        return BatteryReading(level: level, state: state, date: Date())
    }
}
