import SwiftUI
import WidgetKit

struct BatteryEntry: TimelineEntry {
    let date: Date
    let level: Int?
    let threshold: Int
    let state: ChargeState
    let updatedAt: Date?

    static let placeholder = BatteryEntry(date: .now, level: 72, threshold: 80, state: .charging, updatedAt: .now)
}

/// 워치 앱이 App Group 에 저장한 최신값을 표시한다. 갱신은 워치 앱의 reloadAllTimelines() 호출로 이루어진다.
struct BatteryProvider: TimelineProvider {
    func placeholder(in context: Context) -> BatteryEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) {
        completion(context.isPreview ? .placeholder : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .after(.now.addingTimeInterval(AppConstants.defaultRefreshInterval))))
    }

    private func currentEntry() -> BatteryEntry {
        BatteryEntry(
            date: .now,
            level: SharedDefaults.latestLevel,
            threshold: SharedDefaults.threshold,
            state: SharedDefaults.latestState,
            updatedAt: SharedDefaults.latestDate
        )
    }
}

struct BatteryComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BatteryEntry

    private var levelText: String { entry.level.map { "\($0)%" } ?? "--" }
    private var fraction: Double { Double(entry.level ?? 0) / 100 }
    private var icon: String { entry.state.isOnCharger ? "bolt.fill" : "battery.75percent" }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: fraction) {
                Image(systemName: icon)
            } currentValueLabel: {
                Text(entry.level.map(String.init) ?? "--")
            }
            .gaugeStyle(.accessoryCircular)

        case .accessoryCorner:
            Text(levelText)
                .widgetLabel {
                    Gauge(value: fraction) { Text("") }
                        .gaugeStyle(.accessoryLinear)
                }

        case .accessoryInline:
            Label("\(levelText) → \(entry.threshold)%", systemImage: icon)

        default: // .accessoryRectangular
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: icon)
                    Text(levelText).font(.headline)
                    Text(entry.state.label).font(.caption).foregroundStyle(.secondary)
                }
                Text("알림 임계값 \(entry.threshold)%").font(.caption)
                if let updatedAt = entry.updatedAt {
                    Text(updatedAt, style: .time).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@main
struct BatteryComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConstants.widgetKind, provider: BatteryProvider()) { entry in
            BatteryComplicationView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("워치 충전 알림")
        .description("현재 배터리와 알림 임계값")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
