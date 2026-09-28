# 프로젝트: Apple Watch 배터리 임계값 충전 알림 앱 (개인용)

## 목표
Apple Watch가 충전 중일 때 배터리가 설정한 임계값(기본 80%)에 도달하면 아이폰으로 알림을 보낸다.
iOS 단축어/Scriptable은 워치 배터리를 읽을 수 없으므로, 워치 앱이 직접 배터리를 읽고 아이폰 컴패니언 앱에 전달하는 구조로 만든다.

## 환경
- Xcode 26, Swift 6, SwiftUI
- watchOS 26 / iOS 26 최소 지원
- 구성: iOS 컴패니언 앱 + watchOS 앱 + WidgetKit 컴플리케이션
- 개인 사용 목적이며 App Store 배포는 하지 않음

## 핵심 기능
1. 워치에서 배터리 읽기
   - `WKInterfaceDevice.current().isBatteryMonitoringEnabled = true`
   - `batteryLevel`, `batteryState`(.charging / .full / .unplugged) 사용
2. 알림 조건
   - `batteryState`가 충전 중이고 `batteryLevel >= 임계값`이면 알림
   - 충전 1회당 알림은 1번만 보냄. 충전기에서 분리(.unplugged)되거나 배터리가 `임계값 - 5%` 미만으로 내려가면 상태를 초기화
   - 임계값은 워치 앱과 아이폰 앱 양쪽에서 50~100% 범위로 설정 가능. 기본값 80. 두 기기 간 동기화
3. 알림 전달 (충전 중인 워치는 손목에 없으므로 아이폰 알림이 주 목적)
   - 1순위: `WCSession.sendMessage`로 아이폰 앱에 전달. 아이폰 앱이 백그라운드에서 깨어나 `UNUserNotificationCenter`로 로컬 알림 표시
   - 2순위: 도달 불가 시 `transferUserInfo`로 큐잉하고 워치 자체 로컬 알림도 함께 발송
   - 선택: 설정에 Webhook URL(예: ntfy 서버 주소)을 입력하면 워치에서 HTTP POST도 함께 보냄. 비어 있으면 사용 안 함
4. 백그라운드 확인 주기
   - SwiftUI `.backgroundTask(.appRefresh)`와 `WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate:)` 사용
   - 확인할 때마다 (시각, 배터리%) 기록을 쌓고, 충전 속도(%/분)를 추정해서 임계값 도달 예상 시각 근처로 다음 refresh를 예약. 예상 불가 시 기본 15분 간격
   - 컴플리케이션을 활성 워치 페이스에 올리면 백그라운드 예산이 늘어나므로, 현재 배터리%와 임계값을 표시하는 WidgetKit 컴플리케이션을 만들고 refresh 때 `WidgetCenter.shared.reloadAllTimelines()` 호출

## 검증용 디버그 화면 (필수)
워치 백그라운드 실행 빈도는 실제 기기에서 보장되지 않으므로, 먼저 실측할 수 있게 한다.
- 워치 앱과 아이폰 앱에 "로그" 화면: 백그라운드 wake 시각, 배터리%, batteryState, 알림 발송 여부, 전달 경로(sendMessage/transferUserInfo/webhook), 실패 사유
- 최근 200건만 보관
- 로그 초기화 버튼

## 산출물 요구사항
- 부분 스니펫이 아닌 **전체 파일**로 작성
- 먼저 Xcode 프로젝트 구조(타깃, 파일 트리, 필요한 Capability와 Info.plist 항목)를 제시하고, 그다음 파일별 전체 코드
- 설정 방법: Signing, App Groups, 백그라운드 모드, 알림 권한 요청 흐름
- 실기기 테스트 절차: 워치를 60%대에서 충전 시작 → 로그로 wake 간격과 알림 도착 지연 확인
- 불확실하거나 애플 문서로 확인되지 않는 동작(예: 충전 중 백그라운드 refresh 빈도)은 추측하지 말고 "검증 필요"로 명시

## 하지 말 것
- HKWorkoutSession 등 운동 세션을 이용해 백그라운드를 강제로 유지하는 우회 방식은 쓰지 않음 (배터리 소모, 운동 기록 오염)
- 외부 라이브러리 의존성 추가 금지
