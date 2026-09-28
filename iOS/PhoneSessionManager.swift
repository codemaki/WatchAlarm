import Foundation
import Observation
import WatchConnectivity

@MainActor
@Observable
final class PhoneSessionManager: NSObject, WCSessionDelegate {
    static let shared = PhoneSessionManager()

    private(set) var isPaired = false
    private(set) var isWatchAppInstalled = false
    private(set) var isReachable = false
    private(set) var threshold = SharedDefaults.threshold
    private(set) var webhookURL = SharedDefaults.webhookURL

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.delegate == nil else { return }
        session.delegate = self
        session.activate()
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
        pushSettings()
    }

    private func pushSettings() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        do {
            try session.updateApplicationContext(SettingsSync.makeContext())
        } catch {
            LogStore.shared.append(LogEntry(date: Date(), event: "설정 동기화 전송 실패", failures: [error.localizedDescription]))
        }
    }

    private func applyIncomingSettings(_ incoming: SettingsSync.Incoming) {
        guard SettingsSync.apply(incoming) else { return }
        threshold = SharedDefaults.threshold
        webhookURL = SharedDefaults.webhookURL
        LogStore.shared.append(LogEntry(date: Date(), event: "설정 동기화 수신", notes: ["임계값 \(threshold)%"]))
    }

    private func updateStatus(paired: Bool, installed: Bool, reachable: Bool) {
        isPaired = paired
        isWatchAppInstalled = installed
        isReachable = reachable
    }

    // MARK: WCSessionDelegate (백그라운드 큐에서 호출됨 → MainActor 로 전환)

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let paired = session.isPaired, installed = session.isWatchAppInstalled, reachable = session.isReachable
        let incoming = SettingsSync.parse(session.receivedApplicationContext)
        let activated = activationState == .activated
        Task { @MainActor in
            self.updateStatus(paired: paired, installed: installed, reachable: reachable)
            if let incoming { self.applyIncomingSettings(incoming) }
            if activated { self.pushSettings() }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // 워치 전환 시 새 워치와 다시 연결
        WCSession.default.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let paired = session.isPaired, installed = session.isWatchAppInstalled, reachable = session.isReachable
        Task { @MainActor in self.updateStatus(paired: paired, installed: installed, reachable: reachable) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let paired = session.isPaired, installed = session.isWatchAppInstalled, reachable = session.isReachable
        Task { @MainActor in self.updateStatus(paired: paired, installed: installed, reachable: reachable) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let incoming = SettingsSync.parse(applicationContext) else { return }
        Task { @MainActor in self.applyIncomingSettings(incoming) }
    }

    /// 1순위 경로: 워치 sendMessage. 알림 등록 후 응답해서 워치가 성공 여부를 알 수 있게 한다.
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let payload = AlertPayload(dictionary: message) else {
            replyHandler([MessageKey.ok: false, MessageKey.error: "알 수 없는 메시지"])
            return
        }
        let reply = ReplyBox(replyHandler)
        Task { @MainActor in
            let error = await PhoneAlertHandler.handle(payload, route: "sendMessage")
            reply.send([MessageKey.ok: error == nil, MessageKey.error: error ?? ""])
        }
    }

    /// 2순위 경로: 워치 transferUserInfo (큐잉되어 나중에 도착할 수 있음)
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let payload = AlertPayload(dictionary: userInfo) else { return }
        Task { @MainActor in
            _ = await PhoneAlertHandler.handle(payload, route: "transferUserInfo")
        }
    }
}

/// replyHandler 를 MainActor 로 넘기기 위한 박스
private final class ReplyBox: @unchecked Sendable {
    private let handler: ([String: Any]) -> Void
    init(_ handler: @escaping ([String: Any]) -> Void) { self.handler = handler }
    func send(_ reply: [String: Any]) { handler(reply) }
}

@MainActor
enum PhoneAlertHandler {
    /// 로컬 알림 표시 + 로그. 실패 시 사유 반환.
    static func handle(_ payload: AlertPayload, route: String) async -> String? {
        let received = Date()
        var entry = LogEntry(date: received, event: "수신: \(route)" + (payload.isTest ? " (테스트)" : ""),
                             level: payload.level, state: payload.state)
        entry.notes.append(String(format: "지연 %.1f초 (워치 발송 → 아이폰 수신)", received.timeIntervalSince(payload.timestamp)))
        entry.notes.append("워치 발송 시각 \(payload.timestamp.formatted(date: .omitted, time: .standard))")

        if SharedDefaults.handledAlertIDs.contains(payload.id) {
            entry.notes.append("이미 처리한 알림 → 중복 무시")
            LogStore.shared.append(entry)
            return nil
        }

        let error = await LocalNotifier.post(payload)
        if let error {
            entry.failures.append(error)
        } else {
            entry.notified = true
            entry.routes.append("아이폰 로컬 알림")
            SharedDefaults.handledAlertIDs.append(payload.id)
        }
        LogStore.shared.append(entry)
        return error
    }
}
