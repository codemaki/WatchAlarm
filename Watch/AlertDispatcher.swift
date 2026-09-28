import Foundation

/// 알림 전달: 1순위 sendMessage → 실패 시 transferUserInfo(큐) + 워치 로컬 알림. Webhook 은 병렬로 추가 발송.
@MainActor
enum AlertDispatcher {
    struct Outcome {
        var routes: [String] = []
        var failures: [String] = []
    }

    static func dispatch(_ payload: AlertPayload) async -> Outcome {
        var outcome = Outcome()
        let webhookURL = SharedDefaults.webhookURL
        async let webhook = WebhookSender.send(payload, to: webhookURL)

        let session = WatchSessionManager.shared
        await session.waitUntilActivated(timeout: 3)

        if let error = await session.sendAlertMessage(payload) {
            outcome.failures.append("sendMessage: \(error)")

            if let error = session.transferAlert(payload) {
                outcome.failures.append("transferUserInfo: \(error)")
            } else {
                outcome.routes.append("transferUserInfo (큐잉)")
            }

            if let error = await LocalNotifier.post(payload) {
                outcome.failures.append("워치 로컬 알림: \(error)")
            } else {
                outcome.routes.append("워치 로컬 알림")
            }
        } else {
            outcome.routes.append("sendMessage ✓ (아이폰 응답 받음)")
        }

        switch await webhook {
        case .skipped: break
        case .success(let code): outcome.routes.append("webhook HTTP \(code)")
        case .failure(let reason): outcome.failures.append("webhook: \(reason)")
        }
        return outcome
    }
}
