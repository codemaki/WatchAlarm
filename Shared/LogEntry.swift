import Foundation

/// 디버그 로그 1건
struct LogEntry: Codable, Identifiable, Sendable {
    var id = UUID()
    /// 이벤트 발생(= wake) 시각
    var date: Date
    /// 이벤트 종류 (예: "백그라운드 refresh", "포그라운드", "수신: sendMessage")
    var event: String
    var level: Int?
    var state: ChargeState?
    /// 이 이벤트에서 알림을 발송했는지
    var notified: Bool = false
    /// 전달 경로 (예: "sendMessage ✓", "transferUserInfo(큐)", "webhook 200")
    var routes: [String] = []
    /// 실패 사유
    var failures: [String] = []
    /// 기타 메모 (다음 예약 시각, 상태 초기화 사유 등)
    var notes: [String] = []
}
