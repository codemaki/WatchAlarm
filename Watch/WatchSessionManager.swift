import Foundation
import Observation
import WatchConnectivity

@MainActor
@Observable
final class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    private(set) var isReachable = false
    private(set) var isActivated = false

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.delegate == nil else { return }
        session.delegate = self
        session.activate()
    }

    func waitUntilActivated(timeout: TimeInterval) async {
        activate()
        let deadline = Date().addingTimeInterval(timeout)
        while WCSession.default.activationState != .activated, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// .backgroundTask(.watchConnectivity) 에서 받은 데이터를 모두 처리할 때까지 대기
    func waitForPendingContent() async {
        await waitUntilActivated(timeout: 5)
        let deadline = Date().addingTimeInterval(10)
        while WCSession.default.hasContentPending, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    /// sendMessage 로 아이폰에 전달하고 응답을 기다린다. 성공 시 nil, 실패 시 사유.
    func sendAlertMessage(_ payload: AlertPayload, timeout: TimeInterval = 8) async -> String? {
        let session = WCSession.default
        guard session.activationState == .activated else { return "WCSession 비활성" }
        guard session.isReachable else { return "iPhone 도달 불가 (isReachable=false)" }

        return await withCheckedContinuation { continuation in
            let once = ResumeOnce(continuation)
            session.sendMessage(payload.dictionary, replyHandler: { reply in
                if reply[MessageKey.ok] as? Bool == true {
                    once.resume(nil)
                } else {
                    once.resume("아이폰 처리 실패: \(reply[MessageKey.error] as? String ?? "알 수 없음")")
                }
            }, errorHandler: { error in
                once.resume(error.localizedDescription)
            })
            Task {
                try? await Task.sleep(for: .seconds(timeout))
                once.resume("응답 타임아웃 \(Int(timeout))초")
            }
        }
    }

    /// 아이폰이 도달 불가일 때 큐잉. 실제 전달 결과는 didFinish userInfoTransfer 에서 로그로 남김.
    func transferAlert(_ payload: AlertPayload) -> String? {
        let session = WCSession.default
        guard session.activationState == .activated else { return "WCSession 비활성" }
        session.transferUserInfo(payload.dictionary)
        return nil
    }

    func pushSettings() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        do {
            try session.updateApplicationContext(SettingsSync.makeContext())
        } catch {
            LogStore.shared.append(LogEntry(date: Date(), event: "설정 동기화 전송 실패", failures: [error.localizedDescription]))
        }
    }

    // MARK: WCSessionDelegate (백그라운드 큐에서 호출됨 → MainActor 로 전환)

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let activated = activationState == .activated
        let reachable = session.isReachable
        let incoming = SettingsSync.parse(session.receivedApplicationContext)
        Task { @MainActor in
            self.isActivated = activated
            self.isReachable = reachable
            if let incoming { WatchModel.shared.applyIncomingSettings(incoming) }
            // 아이폰이 모르는 최신 설정이 워치에 있으면 보냄
            if activated { self.pushSettings() }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let incoming = SettingsSync.parse(applicationContext) else { return }
        Task { @MainActor in WatchModel.shared.applyIncomingSettings(incoming) }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        let level = userInfoTransfer.userInfo[MessageKey.level] as? Int
        let message = error?.localizedDescription
        Task { @MainActor in
            var entry = LogEntry(date: Date(), event: "transferUserInfo 전달 완료", level: level)
            if let message {
                entry.event = "transferUserInfo 전달 실패"
                entry.failures = [message]
            }
            LogStore.shared.append(entry)
        }
    }
}

/// continuation 을 정확히 한 번만 resume 하기 위한 헬퍼
final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String?, Never>?

    init(_ continuation: CheckedContinuation<String?, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: String?) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}
