import Foundation

/// 선택 기능: ntfy 호환 HTTP POST (본문 평문 + Title/Priority/Tags 헤더)
enum WebhookSender {
    enum Result: Sendable {
        case skipped
        case success(Int)
        case failure(String)
    }

    static func send(_ payload: AlertPayload, to urlString: String) async -> Result {
        guard !urlString.isEmpty else { return .skipped }
        guard let url = URL(string: urlString), let scheme = url.scheme, ["http", "https"].contains(scheme) else {
            return .failure("잘못된 URL")
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.httpBody = Data(payload.body.utf8)
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        // HTTP 헤더는 ASCII 만 안전하므로 제목은 영문
        request.setValue(payload.isTest ? "[Test] Apple Watch Battery" : "Apple Watch Battery \(payload.level)%",
                         forHTTPHeaderField: "Title")
        request.setValue("high", forHTTPHeaderField: "Priority")
        request.setValue("battery,watch", forHTTPHeaderField: "Tags")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            return (200..<300).contains(code) ? .success(code) : .failure("HTTP \(code)")
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}
