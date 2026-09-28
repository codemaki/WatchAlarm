import SwiftUI

struct WatchRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let model = WatchModel.shared
    private let session = WatchSessionManager.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.reading?.level.map { "\($0)%" } ?? "--%")
                            .font(.system(size: 40, weight: .semibold, design: .rounded))
                        Text(model.reading?.state.label ?? "-")
                            .foregroundStyle(model.reading?.state.isOnCharger == true ? .green : .secondary)
                        Text("임계값 \(model.threshold)%" + (model.alerted ? " · 알림 보냄" : ""))
                            .font(.footnote)
                    }
                }

                Section {
                    Button {
                        Task { await model.performCheck(trigger: .manual) }
                    } label: {
                        Label(model.isChecking ? "확인 중…" : "지금 확인", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.isChecking)

                    NavigationLink { WatchSettingsView() } label: { Label("설정", systemImage: "gear") }
                    NavigationLink { LogListView() } label: { Label("로그", systemImage: "list.bullet") }
                }

                Section("상태") {
                    LabeledContent("iPhone", value: session.isReachable ? "연결됨" : "도달 불가")
                    if let rate = model.rate {
                        LabeledContent("충전 속도", value: String(format: "%.2f%%/분", rate))
                    }
                    if let next = model.nextRefresh {
                        LabeledContent("다음 refresh") {
                            Text(next, style: .time)
                        }
                    }
                }
                .font(.footnote)
            }
            .navigationTitle("GAlarm")
        }
        .task {
            await LocalNotifier.requestAuthorization()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                Task { await model.performCheck(trigger: .foreground) }
            }
        }
    }
}

struct WatchSettingsView: View {
    private let model = WatchModel.shared
    @State private var webhookDraft = ""

    var body: some View {
        List {
            Section("임계값") {
                // Digital Crown 으로 조절
                Picker("임계값", selection: Binding(get: { model.threshold }, set: { model.setThreshold($0) })) {
                    ForEach(Array(AppConstants.thresholdRange), id: \.self) { Text("\($0)%").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(height: 60)
            }

            Section {
                TextField("https://ntfy.sh/토픽", text: $webhookDraft)
                    .textContentType(.URL)
                    .onSubmit { model.setWebhookURL(webhookDraft) }
            } header: {
                Text("Webhook URL")
            } footer: {
                Text("비워두면 사용 안 함. 아이폰 앱에서 입력하는 것이 편합니다.")
            }

            Section {
                Button {
                    Task { await model.sendTest() }
                } label: {
                    Label("테스트 알림", systemImage: "bell.badge")
                }
            }
        }
        .navigationTitle("설정")
        .onAppear { webhookDraft = model.webhookURL }
        .onChange(of: model.webhookURL) { _, value in webhookDraft = value }
    }
}
