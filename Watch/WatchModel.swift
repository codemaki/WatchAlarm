import Foundation
import Observation
import WidgetKit

enum CheckTrigger: String {
    case backgroundRefresh = "백그라운드 refresh"
    case foreground = "포그라운드"
    case manual = "수동 확인"
}

@MainActor
@Observable
final class WatchModel {
    static let shared = WatchModel()

    private(set) var reading: BatteryReading?
    private(set) var threshold = SharedDefaults.threshold
    private(set) var webhookURL = SharedDefaults.webhookURL
    private(set) var alerted = SharedDefaults.alertedForCurrentCharge
    private(set) var nextRefresh = SharedDefaults.nextRefreshDate
    private(set) var rate: Double?
    private(set) var isChecking = false

    private init() {}

    /// 배터리 확인 → 알림 판단/발송 → 다음 refresh 예약 → 컴플리케이션 갱신 → 로그
    func performCheck(trigger: CheckTrigger) async {
        isChecking = true
        defer { isChecking = false }

        let reading = BatteryReader.read()
        self.reading = reading
        SharedDefaults.latestLevel = reading.level
        SharedDefaults.latestState = reading.state
        SharedDefaults.latestDate = reading.date

        let threshold = SharedDefaults.threshold
        let decision = ChargeTracker.evaluate(reading, threshold: threshold)

        var entry = LogEntry(date: reading.date, event: trigger.rawValue, level: reading.level, state: reading.state)
        if reading.level == nil { entry.failures.append("batteryLevel 읽기 실패 (-1)") }
        if let reason = decision.resetReason { entry.notes.append(reason) }

        if decision.shouldAlert, let level = reading.level {
            let payload = AlertPayload(level: level, threshold: threshold, state: reading.state)
            let outcome = await AlertDispatcher.dispatch(payload)
            entry.notified = true
            entry.routes = outcome.routes
            entry.failures += outcome.failures
        }

        rate = ChargeTracker.estimatedRatePerMinute()
        let next = ChargeTracker.nextRefresh(after: reading, threshold: threshold)
        if let error = await RefreshScheduler.schedule(at: next.date) {
            entry.failures.append("refresh 예약 실패: \(error)")
        } else {
            entry.notes.append("다음 예약 \(next.date.formatted(date: .omitted, time: .shortened)) · \(next.reason)")
        }
        nextRefresh = SharedDefaults.nextRefreshDate
        alerted = SharedDefaults.alertedForCurrentCharge

        WidgetCenter.shared.reloadAllTimelines()
        LogStore.shared.append(entry)
    }

    /// 전달 경로 점검용 테스트 알림 (알림 상태에는 영향 없음)
    func sendTest() async {
        let current = BatteryReader.read()
        let payload = AlertPayload(level: current.level ?? 0, threshold: threshold, state: current.state, isTest: true)
        let outcome = await AlertDispatcher.dispatch(payload)
        LogStore.shared.append(LogEntry(
            date: payload.timestamp, event: "테스트 알림", level: current.level, state: current.state,
            notified: true, routes: outcome.routes, failures: outcome.failures
        ))
    }

    // MARK: 설정

    func setThreshold(_ value: Int) {
        let value = SharedDefaults.clampThreshold(value)
        guard value != threshold else { return }
        SharedDefaults.threshold = value
        threshold = value
        settingsChanged()
    }

    func setWebhookURL(_ value: String) {
        SharedDefaults.webhookURL = value
        webhookURL = SharedDefaults.webhookURL
        settingsChanged()
    }

    private func settingsChanged() {
        SharedDefaults.settingsUpdatedAt = Date()
        // 임계값이 바뀌면 새 기준으로 다시 알릴 수 있도록 초기화
        SharedDefaults.alertedForCurrentCharge = false
        alerted = false
        WatchSessionManager.shared.pushSettings()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func applyIncomingSettings(_ incoming: SettingsSync.Incoming) {
        guard SettingsSync.apply(incoming) else { return }
        threshold = SharedDefaults.threshold
        webhookURL = SharedDefaults.webhookURL
        SharedDefaults.alertedForCurrentCharge = false
        alerted = false
        WidgetCenter.shared.reloadAllTimelines()
        LogStore.shared.append(LogEntry(date: Date(), event: "설정 동기화 수신", notes: ["임계값 \(threshold)%"]))
    }
}
