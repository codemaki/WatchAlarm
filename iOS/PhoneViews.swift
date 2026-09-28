import SwiftUI
import UIKit
import UserNotifications

struct PhoneRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let session = PhoneSessionManager.shared
    @State private var webhookDraft = ""
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            Form {
                Section("워치 연결") {
                    LabeledContent("페어링", value: session.isPaired ? "됨" : "안 됨")
                    LabeledContent("워치 앱 설치", value: session.isWatchAppInstalled ? "됨" : "안 됨")
                    LabeledContent("현재 도달 가능", value: session.isReachable ? "예" : "아니오")
                }

                Section {
                    Stepper(value: Binding(get: { session.threshold }, set: { session.setThreshold($0) }),
                            in: AppConstants.thresholdRange) {
                        LabeledContent("임계값", value: "\(session.threshold)%")
                    }
                    Slider(value: Binding(get: { Double(session.threshold) }, set: { session.setThreshold(Int($0.rounded())) }),
                           in: Double(AppConstants.thresholdRange.lowerBound)...Double(AppConstants.thresholdRange.upperBound),
                           step: 1)
                } header: {
                    Text("알림 임계값")
                } footer: {
                    Text("워치 앱과 자동 동기화됩니다.")
                }

                Section {
                    TextField("https://ntfy.sh/내토픽", text: $webhookDraft)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { session.setWebhookURL(webhookDraft) }
                    if webhookDraft != session.webhookURL {
                        Button("저장") { session.setWebhookURL(webhookDraft) }
                    }
                } header: {
                    Text("Webhook (선택)")
                } footer: {
                    Text("입력하면 워치가 알림 시 이 주소로 HTTP POST(ntfy 형식)를 함께 보냅니다. 비워두면 사용 안 함.")
                }

                Section("알림 권한") {
                    LabeledContent("상태", value: authStatus.label)
                    if authStatus == .notDetermined {
                        Button("권한 요청") { Task { await requestAuth() } }
                    } else if authStatus == .denied {
                        Button("설정 앱 열기") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    Button("아이폰 로컬 알림 테스트") {
                        Task {
                            let payload = AlertPayload(level: session.threshold, threshold: session.threshold,
                                                       state: .charging, isTest: true)
                            _ = await PhoneAlertHandler.handle(payload, route: "아이폰 자체 테스트")
                        }
                    }
                }

                Section {
                    NavigationLink("로그") { LogListView() }
                }
            }
            .navigationTitle("워치 충전 알림")
        }
        .task { await requestAuth() }
        .onAppear { webhookDraft = session.webhookURL }
        .onChange(of: session.webhookURL) { _, value in webhookDraft = value }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { authStatus = await LocalNotifier.authorizationStatus() } }
        }
    }

    private func requestAuth() async {
        if await LocalNotifier.authorizationStatus() == .notDetermined {
            await LocalNotifier.requestAuthorization()
        }
        authStatus = await LocalNotifier.authorizationStatus()
    }
}

private extension UNAuthorizationStatus {
    var label: String {
        switch self {
        case .notDetermined: "요청 전"
        case .denied: "거부됨"
        case .authorized: "허용"
        case .provisional: "임시 허용"
        case .ephemeral: "임시"
        @unknown default: "알 수 없음"
        }
    }
}
