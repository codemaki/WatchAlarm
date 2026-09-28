# GAlarm App Store 제출 가이드

## 1. 코드/프로젝트에 이미 반영된 것

| 항목 | 내용 |
|---|---|
| 앱 이름(홈 화면) | `GAlarm` (iOS, watchOS, 컴플리케이션) |
| 앱 아이콘 | `iOS/Assets.xcassets`, `Watch/Assets.xcassets` — 1024×1024, 알파 없음 (`scripts/make_icon.swift`로 원본에서 생성) |
| 수출 규정 | `ITSAppUsesNonExemptEncryption = NO` (HTTPS 외 자체 암호화 없음) → 업로드 때마다 묻지 않음 |
| 개인정보 매니페스트 | 3개 타깃 모두 `PrivacyInfo.xcprivacy` (UserDefaults 사유 CA92.1 / 1C8F.1, 수집 데이터 없음, 추적 없음) |
| 카테고리 | `LSApplicationCategoryType = public.app-category.utilities` |
| 버전 | `project.yml`의 `MARKETING_VERSION`(1.0) / `CURRENT_PROJECT_VERSION`(1) |
| 아카이브 | `scripts/archive.sh` (+ `ExportOptions.plist`, method `app-store-connect`) |

Bundle ID는 기존 그대로입니다(`com.codemaki.WatchAlarm`, `.watchkitapp`, `.watchkitapp.widget`). 바꾸면 App Group/서명을 다시 만들어야 하고, 사용자에게는 보이지 않으므로 유지합니다.

## 2. 직접 해야 하는 것 (App Store Connect)

1. **앱 레코드 생성**: [App Store Connect](https://appstoreconnect.apple.com) → 앱 → ＋ 신규 앱
   - 플랫폼: iOS / 이름: `GAlarm` (이미 사용 중인 이름이면 `GAlarm - 워치 충전 알림` 등으로 변경)
   - 기본 언어: 한국어 / 번들 ID: `com.codemaki.WatchAlarm` / SKU: `galarm-001`
2. **빌드 업로드**
   ```bash
   ./scripts/archive.sh --upload
   ```
   또는 Xcode → Product → Archive → Organizer → Distribute App → App Store Connect.
   다시 올릴 때는 `project.yml`의 `CURRENT_PROJECT_VERSION`을 올리고 실행.
3. **개인정보 처리방침 URL** (필수): `PRIVACY.md`를 공개 URL로 게시
   - GitHub 저장소가 public이면 `https://github.com/codemaki/WatchAlarm/blob/main/PRIVACY.md` 사용 가능
   - private이면 GitHub Pages, Notion 공개 페이지 등에 게시
4. **앱 개인정보 보호(Privacy Nutrition Label)**: "데이터를 수집하지 않음" 선택
5. **스크린샷** (필수)
   - iPhone 6.9형(예: iPhone 17 Pro Max 시뮬레이터) 최소 1장
   - Apple Watch (예: Ultra 49mm 시뮬레이터) 최소 1장 — 워치 앱이 포함된 경우 필요
6. **연령 등급**: 설문 모두 "없음" → 4+
7. **가격**: 무료 / 배포 국가 선택
8. **심사 제출** (아래 메타데이터/심사 메모 사용)

## 3. 메타데이터 초안

**부제 (30자)**: 워치 충전 완료를 아이폰으로 알림

**프로모션 텍스트**: 워치를 충전기에 올려두고 잊어버리셨나요? 원하는 배터리 %에 도달하면 아이폰으로 알려드립니다.

**설명**
```
GAlarm은 Apple Watch가 충전 중일 때 배터리가 설정한 비율(기본 80%)에 도달하면 iPhone으로 알림을 보내 줍니다.

배터리 수명을 위해 워치를 100%까지 충전하지 않고 싶거나, 충전기에 올려둔 워치를 제때 챙기고 싶을 때 유용합니다.

주요 기능
• 알림 임계값 50~100% 설정 (iPhone과 Apple Watch에서 자동 동기화)
• 충전 1회당 한 번만 알림, 충전기 분리 시 자동 초기화
• iPhone 연결이 안 될 때는 워치 자체 알림으로 대체
• 워치 페이스 컴플리케이션으로 현재 배터리와 임계값 표시
• 선택: Webhook(ntfy 등) 주소로 알림 전송
• 동작 확인용 로그 화면

참고
• 워치 앱은 watchOS의 백그라운드 새로고침 일정에 따라 배터리를 확인하므로, 알림이 임계값 도달 직후가 아니라 수 분 늦게 올 수 있습니다.
• 워치 페이스에 GAlarm 컴플리케이션을 추가하면 확인 빈도가 높아집니다.
• 개인정보를 수집하지 않습니다.
```

**키워드 (100자)**: `애플워치,배터리,충전,알림,충전완료,워치,배터리알림,80%,배터리보호,watch,battery,charge`

**지원 URL**: `https://github.com/codemaki/WatchAlarm` (또는 이메일 안내 페이지)

## 4. 심사 메모 (App Review Information → Notes)

```
GAlarm notifies the user on iPhone when their Apple Watch, while charging, reaches a battery threshold they chose (default 80%).

How to test:
1. Install the iPhone app; the Apple Watch app installs with it. Allow notifications on both devices.
2. On Apple Watch, open GAlarm → 설정(Settings) → 테스트 알림(Test notification). An iPhone notification appears immediately. This verifies the delivery path without waiting for charging.
3. For the real flow: set the threshold slightly above the current battery level, put the watch on the charger. When the watch app's background refresh runs after the level reaches the threshold, a notification is shown on iPhone.

Notes:
- Battery is read with WKInterfaceDevice battery monitoring during scheduled background app refresh (no workout sessions or other background-keeping techniques).
- Time Sensitive notifications are used so the charging-complete alert can break through Focus.
- The optional webhook URL is entered by the user and only sends to the user's own server. The app collects no data.
- No login is required.
```

## 5. 심사 리스크 (확인 필요)

- **4.2 최소 기능**: 기능이 단순하다고 판단될 수 있습니다. 거절되면 설명에 활용 시나리오를 보강하거나 기능 추가가 필요할 수 있습니다.
- **Time Sensitive 알림**: 용도가 적절한지 심사에서 물을 수 있습니다(심사 메모에 명시함).
- **디버그 로그 화면**: 개발용으로 보일 수 있으나 동작 확인 기능으로 설명 가능. 문제가 되면 설정 안쪽으로 옮기는 것을 고려.
- **이름 중복**: `GAlarm`이 이미 등록된 이름이면 App Store Connect에서 거부되므로 부제형 이름으로 변경 필요. 홈 화면 표시 이름(`CFBundleDisplayName`)은 `GAlarm` 그대로 둘 수 있습니다.
