import SwiftUI

/// 디버그 로그 화면 (아이폰 / 워치 공용)
struct LogListView: View {
    private let store = LogStore.shared
    @State private var confirmClear = false

    var body: some View {
        List {
            if store.entries.isEmpty {
                Text("로그 없음").foregroundStyle(.secondary)
            }
            ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                let previous = index + 1 < store.entries.count ? store.entries[index + 1] : nil
                LogRow(entry: entry, previous: previous)
            }
        }
        .navigationTitle("로그 \(store.entries.count)")
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("초기화", systemImage: "trash", role: .destructive) { confirmClear = true }
                    .disabled(store.entries.isEmpty)
            }
        }
        .confirmationDialog("로그를 모두 지울까요?", isPresented: $confirmClear) {
            Button("초기화", role: .destructive) { store.clear() }
        }
    }
}

private struct LogRow: View {
    let entry: LogEntry
    let previous: LogEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.date, format: .dateTime.month(.twoDigits).day(.twoDigits).hour().minute().second())
                    .font(.caption.monospacedDigit())
                Spacer()
                if let previous {
                    // 이전 로그와의 간격 → wake 간격 측정용
                    Text("+" + Self.interval(entry.date.timeIntervalSince(previous.date)))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 4) {
                if entry.notified { Image(systemName: "bell.fill").foregroundStyle(.orange) }
                Text(entry.event).font(.footnote.bold())
            }
            if entry.level != nil || entry.state != nil {
                Text("\(entry.level.map { "\($0)%" } ?? "-%") · \(entry.state?.label ?? "-")")
                    .font(.footnote)
            }
            ForEach(entry.routes, id: \.self) { Text("→ \($0)").font(.caption2).foregroundStyle(.green) }
            ForEach(entry.failures, id: \.self) { Text("✗ \($0)").font(.caption2).foregroundStyle(.red) }
            ForEach(entry.notes, id: \.self) { Text($0).font(.caption2).foregroundStyle(.secondary) }
        }
    }

    private static func interval(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s < 60 { return "\(s)초" }
        if s < 3600 { return "\(s / 60)분 \(s % 60)초" }
        return "\(s / 3600)시간 \(s % 3600 / 60)분"
    }
}
