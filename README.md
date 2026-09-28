# WatchAlarm — Apple Watch 충전 임계값 알림 (개인용)

워치가 충전 중일 때 배터리가 임계값(기본 80%)에 도달하면 아이폰으로 알림을 보냅니다.

## 1. 프로젝트 구조

XcodeGen(`project.yml`)으로 `.xcodeproj`를 생성합니다. `.xcodeproj`는 git에 넣지 않습니다.

```bash
xcodegen generate && open WatchAlarm.xcodeproj
```

| 타깃 | 플랫폼 | Bundle ID | 소스 |
|---|---|---|---|
| `WatchAlarm` | iOS 26 | `com.codemaki.WatchAlarm` | iOS, Shared, SharedApp |
| `WatchAlarmWatch` | watchOS 26 | `com.codemaki.WatchAlarm.watchkitapp` | Watch, Shared, SharedApp |
| `WatchAlarmWidget` | watchOS 26 (WidgetKit ext) | `com.codemaki.WatchAlarm.watchkitapp.widget` | Widget, Shared |

임베드 구조: `WatchAlarm.app/Watch/WatchAlarmWatch.app/PlugIns/WatchAlarmWidget.appex`

```
Shared/            모든 타깃 공용 (위젯 포함)
  AppConstants.swift     상수, WCSession 메시지 키
  ChargeState.swift      charging/full/unplugged/unknown
  AlertPayload.swift     워치→아이폰 알림 메시지
  LogEntry.swift         로그 1건 모델
  SharedDefaults.swift   App Group UserDefaults (설정, 최신 배터리, 샘플, 로그)
  SettingsSync.swift     임계값/Webhook 양방향 동기화 (applicationContext, 최신값 우선)
SharedApp/         iOS + watchOS 앱 공용
  LogStore.swift         최근 200건 로그
  LocalNotifier.swift    로컬 알림 + 포그라운드 배너 delegate
  LogListView.swift      로그 화면 (wake 간격 "+n분" 표시, 초기화 버튼)
Watch/
  WatchAlarmWatchApp.swift   @main, .backgroundTask(.appRefresh / .watchConnectivity)
  BatteryReader.swift        WKInterfaceDevice 배터리 읽기
  ChargeTracker.swift        알림 조건, 충전속도 추정, 다음 refresh 시각 계산
  RefreshScheduler.swift     scheduleBackgroundRefresh
  AlertDispatcher.swift      sendMessage → (실패) transferUserInfo + 워치 알림, webhook 병렬
  WebhookSender.swift        ntfy 호환 POST
  WatchSessionManager.swift  WCSession (워치)
  WatchModel.swift           확인 흐름 전체 조율
  WatchViews.swift           상태 / 설정 / 테스트 알림
iOS/
  WatchAlarmApp.swift        @main + AppDelegate (백그라운드 실행 시 WCSession 활성화)
  PhoneSessionManager.swift  WCSession (아이폰), 알림 수신 → 로컬 알림, 중복 제거
  PhoneViews.swift           임계값, Webhook, 알림 권한, 로그
Widget/
  BatteryComplication.swift  circular / rectangular / inline / corner 컴플리케이션
```

### Capability / Entitlements (project.yml에서 자동 생성)

| 타깃 | Capability |
|---|---|
| iOS | App Groups `group.com.codemaki.watchalarm`, Time Sensitive Notifications |
| Watch | App Groups `group.com.codemaki.watchalarm` |
| Widget | App Groups `group.com.codemaki.watchalarm` |

- App Group은 **같은 기기 안에서만** 공유됩니다(워치 앱 ↔ 컴플리케이션). 워치 ↔ 아이폰은 WCSession으로 동기화합니다.
- 백그라운드 모드(`UIBackgroundModes`, `WKBackgroundModes`)는 **필요 없습니다.** watchOS 백그라운드 app refresh와 WCSession의 아이폰 백그라운드 실행에는 별도 모드가 필요하지 않습니다.

### Info.plist 주요 항목

- Watch: `WKApplication = YES`, `WKCompanionAppBundleIdentifier = com.codemaki.WatchAlarm`
- Widget: `NSExtension.NSExtensionPointIdentifier = com.apple.widgetkit-extension`
- iOS: `UILaunchScreen`

## 2. 설정 방법

1. **Signing**: `project.yml`에 Team `W345C6H54N` / Automatic signing으로 설정되어 있습니다. Xcode에서 세 타깃 모두 Signing & Capabilities에 오류가 없는지 확인하세요. App Group ID는 자동 서명 시 Developer 계정에 자동 등록됩니다.
   - Time Sensitive 알림 capability 때문에 서명이 실패하면 `project.yml`의 `com.apple.developer.usernotifications.time-sensitive` 줄을 지우고 다시 `xcodegen generate` 하세요(알림은 일반 수준으로 동작).
2. **설치**: 아이폰을 연결하고 `WatchAlarm` 스킴을 실행하면 워치 앱도 같이 설치됩니다. 워치에 바로 설치하려면 `WatchAlarmWatch` 스킴을 선택하고 워치를 대상으로 실행하세요. 워치/아이폰 모두 개발자 모드가 켜져 있어야 합니다.
3. **알림 권한 요청 흐름**
   - 아이폰: 앱 첫 실행 시 요청. 화면의 "알림 권한" 섹션에서 상태 확인, 거부된 경우 "설정 앱 열기".
   - 워치: 워치 앱 첫 실행 시 요청 (2순위 경로인 워치 로컬 알림에 필요).
   - 아이폰에서 알림이 오면 아이폰 잠금 상태일 때 워치로도 미러링될 수 있습니다(iOS 기본 동작).
4. **컴플리케이션**: 워치 페이스 편집 → 컴플리케이션 → "충전알림" 추가. 활성 페이스에 컴플리케이션이 있으면 백그라운드 실행 예산이 늘어납니다(Apple 문서 기준. 실제 빈도는 아래 "검증 필요").
5. **Webhook (선택)**: 아이폰 앱에 `https://ntfy.sh/<토픽>` 같은 주소를 입력하면 워치로 동기화되고, 알림 시 워치가 직접 POST 합니다(본문 평문, `Title`/`Priority: high`/`Tags` 헤더).

## 3. 동작 요약

1. 백그라운드 refresh(또는 앱 실행/수동 확인)마다 배터리 읽기 → 컴플리케이션용 값 저장
2. `충전 중/완충 && level >= 임계값 && 이번 충전에서 미발송` → 알림
3. 분리(`unplugged`) 또는 `level < 임계값 - 5` 이면 상태 초기화. 임계값을 바꿔도 초기화.
4. 전달: `sendMessage`(아이폰 응답까지 최대 8초 대기) 성공 → 끝. 실패 → `transferUserInfo` 큐잉 + 워치 로컬 알림. Webhook은 설정 시 항상 병렬 발송.
5. 충전 중 샘플(시각, %)로 %/분 추정 → 임계값 도달 예상 시각+1분(5~60분 범위)으로 다음 refresh 예약. 추정 불가/미충전/발송 완료 후엔 15분.
6. `WidgetCenter.shared.reloadAllTimelines()` 호출, 로그 기록.

## 4. 실기기 테스트 절차

1. 워치/아이폰 앱을 설치하고 두 기기에서 알림 권한 허용.
2. 워치 페이스에 컴플리케이션 추가.
3. **경로 점검**: 워치 앱 → 설정 → "테스트 알림".
   - 아이폰 앱 로그: `수신: sendMessage (테스트)` + "지연 n초"가 보이면 1순위 경로 정상.
   - 워치 로그에 `sendMessage ✓` 또는 실패 사유가 남습니다.
   - 아이폰 앱을 스와이프로 종료한 상태에서도 한 번 더 테스트해 아이폰 앱이 백그라운드로 깨어나는지 확인.
4. 임계값을 확인하기 쉬운 값(예: 현재 %+10)으로 설정.
5. 워치를 **60%대에서 충전 시작** → 워치 앱을 한 번 열었다 닫음(첫 refresh 예약).
6. 도달 후 아이폰 알림이 오면 로그 확인:
   - **워치 로그**: `백그라운드 refresh` 항목의 시각과 `+n분`(직전 로그와의 간격) → 실제 wake 간격. 각 항목의 "다음 예약 hh:mm"과 실제 다음 wake 시각을 비교하면 예약 대비 지연을 알 수 있습니다.
   - **아이폰 로그**: `수신: sendMessage` / `수신: transferUserInfo` 의 "지연 n초"(워치 발송→아이폰 수신). 워치 시계와 아이폰 시계 차이가 포함됩니다.
   - 실제 임계값 도달 시각 대비 알림 지연 = (알림 발송 wake 시각) − (도달 시각). 도달 시각은 로그의 연속된 % 값으로 추정.
7. 충전기에서 분리 → 다음 wake 로그에 `상태 초기화: 충전기 분리` 확인.
8. 결과에 따라 임계값을 실제 원하는 값보다 약간 낮게 설정하는 식으로 운용을 조정하세요.

## 5. 검증 필요 (Apple 문서로 보장되지 않는 동작)

- **충전 중 백그라운드 refresh 실제 빈도**: `preferredDate`는 희망값일 뿐입니다. 컴플리케이션이 활성 페이스에 있을 때 대략 시간당 4회 수준으로 알려져 있으나 충전 중/화면 꺼짐/저전력 상태에서의 실제 간격은 **검증 필요**. 5분 예약이 5분에 실행된다는 보장은 없습니다.
- **백그라운드 refresh 중 `WCSession.isReachable`**: 워치 앱이 백그라운드일 때 `isReachable`이 true가 되는지, `sendMessage`가 아이폰 앱을 백그라운드에서 깨우는지는 **검증 필요**. false면 자동으로 `transferUserInfo` + 워치 로컬 알림으로 넘어갑니다.
- **`transferUserInfo` 도착 시점**: 아이폰 앱이 실행 중이 아니면 다음 실행 때까지 전달이 미뤄질 수 있습니다. 백그라운드로 깨워 즉시 알림을 띄우는지는 **검증 필요**. 그래서 이 경우 워치 로컬 알림을 함께 보냅니다(손목에 없으면 놓칠 수 있음 → Webhook 권장).
- **백그라운드 refresh 실행 시간 한도**: sendMessage 응답 대기(최대 8초) + webhook(타임아웃 10초)이 refresh 시간 안에 끝나는지 **검증 필요**. 로그에 "응답 타임아웃"이나 webhook 실패가 자주 보이면 알려주세요.
- **Webhook 네트워크 경로**: 워치가 아이폰 경유/Wi‑Fi로 백그라운드 중 HTTP 요청을 완료할 수 있는지 **검증 필요**.
- **`.backgroundTask(.appRefresh)`**: Xcode 27 SDK에서 deprecated(→ `appRefresh(_ identifier:)`)입니다. 식별자 버전이 `scheduleBackgroundRefresh`의 `userInfo`와 어떻게 매칭되는지 문서화되어 있지 않아, watchOS 26에서 동작하는 기존 형태를 사용했습니다(빌드 경고 1건).
- **컴플리케이션 갱신**: `reloadAllTimelines()`는 WidgetKit 예산 내에서 처리되므로 컴플리케이션 표시가 즉시 바뀌지 않을 수 있습니다.
- **배터리 % 정밀도**: `batteryLevel`의 갱신 단위(1%/5% 등)는 문서화되지 않아 **검증 필요**. 로그에서 % 변화 단위를 확인하세요.
