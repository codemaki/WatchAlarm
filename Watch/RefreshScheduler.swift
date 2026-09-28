import Foundation
import WatchKit

@MainActor
enum RefreshScheduler {
    /// 백그라운드 refresh 예약. 앱당 예약은 1개만 유지되며, 새로 예약하면 이전 예약은 취소된다(WKBackgroundTask.h).
    /// 실제 실행 시각은 시스템이 결정하므로 preferredDate 보다 늦어질 수 있다. 실패 시 사유 반환.
    static func schedule(at date: Date) async -> String? {
        let error: String? = await withCheckedContinuation { continuation in
            WKApplication.shared().scheduleBackgroundRefresh(
                withPreferredDate: date,
                userInfo: AppConstants.refreshUserInfo as NSString
            ) { error in
                continuation.resume(returning: error?.localizedDescription)
            }
        }
        if error == nil { SharedDefaults.nextRefreshDate = date }
        return error
    }
}
