import Foundation
import Observation

/// 디버그 로그 저장소 (최근 200건)
@MainActor
@Observable
final class LogStore {
    static let shared = LogStore()

    private(set) var entries: [LogEntry]

    private init() {
        entries = SharedDefaults.logs
    }

    func append(_ entry: LogEntry) {
        entries.insert(entry, at: 0)
        if entries.count > AppConstants.maxLogEntries {
            entries.removeLast(entries.count - AppConstants.maxLogEntries)
        }
        SharedDefaults.logs = entries
    }

    func clear() {
        entries = []
        SharedDefaults.logs = []
    }
}
