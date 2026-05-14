# SmartOffice-app — 수정 제안 보관 (SUGGESTIONS)

> 본 파일은 다른 레포(주로 10-Capstone 상위 세션 / 백엔드 통합 점검) 진행 중 SmartOffice-app 에서 발견된 수정 제안을 보관하는 곳입니다.
> 10-Capstone 루트 `CLAUDE.md` 5절 "수정 제안 보관 정책" 에 따른 운영 파일.
> append-only — 기존 항목 삭제 금지. 반영 완료 항목은 본문 위쪽에 `[반영됨 YYYY-MM-DD]` 마커만 덧붙입니다.

---

## [반영됨 2026-05-14] [2026-05-14] 급여 명세서 페이지에서 ADMIN 전용 엔드포인트 호출 → 403/400 오류

> 반영 메모: `lib/recpit.dart` `_fetchSalaryRecords` 를 `/auth/me` → `/salary/records/me?year=&month=` 최근 6개월 병렬 호출로 교체. 단건 응답(`SalaryRecordResponse`)을 그대로 누적. 미산출 월(404) 은 무시. 401 한 건이라도 있으면 인증 만료 처리. 백엔드 API 호출 검증 통과 (EMP002 / 2026-05·04 200, 그 외 404).


- **발생 맥락**: SmartOffice-app ↔ SmartOffice-server 연결 점검 중. 앱 개발자가 "급여 명세 페이지 서버 오류"라고 보고.
- **현재 코드** (`lib/recpit.dart` 84-90 행):
  ```dart
  final response = await http.get(
    Uri.parse('$_baseUrl/api/v1/salary/records?userId=$userId'),
    headers: { 'Authorization': 'Bearer $token', ... },
  );
  ```
- **문제**:
  1. `GET /api/v1/salary/records` 는 백엔드에서 `@PreAuthorize("hasRole('ADMIN')")` — 일반 직원 토큰으로 호출 시 **403 Forbidden**.
  2. 동 엔드포인트는 `year`, `month` 가 **필수 RequestParam** — 누락 시 400.
  3. 응답이 `PageResponse<SalaryRecordResponse>` 인데 앱은 `data.content`/`data.records` 배열로 파싱 시도 — 형식이 와도 분기 깨짐.
- **제안 내용**:
  1. 엔드포인트를 **`GET /api/v1/salary/records/me?year={year}&month={month}`** 로 교체. 이 경로는 `@AuthenticationPrincipal` 기반이라 USER 권한으로 호출 가능. 응답은 **단건** `SalaryRecordResponse`.
  2. 현재 UI 의 "월 셀렉터" 구조를 유지하려면 **최근 N개월(예: 6개월) 을 병렬 호출** 후 200/404 로 들어온 결과만 모아 `_salaryRecords` 채우기. (예: `Future.wait([...])`)
  3. 단건 응답이므로 `data.content` 분기 제거. 200 외 응답(특히 404 — 해당 월 미산출)은 무시하고 다음 달로 진행.
  4. 호출 전에 `/auth/me` 로 userId 조회하던 1단계도 **불필요** (서버가 `userDetails.getUsername()` 으로 본인 식별).
- **근거**:
  - 백엔드 컨트롤러: `SmartOffice-server/.../salary/controller/SalaryRecordController.java`
    - `GET /api/v1/salary/records` (52-64 행) — ADMIN 전용.
    - `GET /api/v1/salary/records/me` (42-50 행) — 본인 조회 전용. `year`, `month` 파라미터.
- **우선순위**: 상 (앱 핵심 기능 다운 상태)
- **출처 세션**: 2026-05-14 SmartOffice-app ↔ server 연결 점검 (10-Capstone 상위 세션).

---

## [반영됨 2026-05-14] [2026-05-14] 주차장 페이지 zoneId 매핑이 백엔드 시드와 어긋남 → 초기 화면 빈 그리드

> 반영 메모: `lib/parking.dart` `parkingZones` 를 `{8:'지하1층', 9:'지하2층'}` 로 시드와 일치시키고 초기값을 `parkingZones.keys.first` (=8) 로 변경. 좌측 셀렉터 라벨은 `_zoneShortLabel` 헬퍼로 'B1'/'B2' 표시. 백엔드 호출 검증 통과 (zone 8: 15면 / zone 9: 10면 정상 응답).


- **발생 맥락**: 위와 동일 점검 중. 앱 개발자가 "주차장 zone id 관련 오류"라고 보고.
- **현재 코드** (`lib/parking.dart` 21-23 행):
  ```dart
  static const Map<int, String> parkingZones = {9: '1층'};
  int _selectedZoneId = 1;
  ```
- **문제**:
  1. `_selectedZoneId = 1` → 초기 진입 시 `GET /api/v1/parking/zones/1/spots` 호출. 백엔드 시드(V3) 기준 zone 1 = '1층(사무 공간)' 로 **주차면 0개**. 결과: 200 OK + 빈 `spots` 배열 → LIVE 그리드가 텅 빈 채로 표시되며 사용자는 "오류"로 인지.
  2. `parkingZones` 키 9 의 라벨이 '1층' 으로 잘못 적혀 있음. 실제 zone 9 = **'지하2층'** (V8 시드).
  3. `_buildZoneSelector` 가 `'${entry.key}F'` 로 출력 → 화면에 "9F" 가 표시되며 라벨 맵 자체가 사용되지 않음 (이중 혼선).
- **백엔드 시드 (확정 사실)**:
  | zone_id | 이름 | 주차면 수 | Flyway |
  |---|---|---|---|
  | 1 | 1층 | 0 | V3 |
  | 8 | 지하1층 | 15 | V5 + V8 |
  | 9 | 지하2층 | 10 | V8 |
- **제안 내용**:
  1. `parkingZones` 를 백엔드 시드와 일치시키기:
     ```dart
     static const Map<int, String> parkingZones = {
       8: '지하1층',
       9: '지하2층',
     };
     ```
  2. 초기 `_selectedZoneId` 를 주차면이 있는 zone 중 하나(예: `8`)로 변경. 또는 `parkingZones.keys.first` 로 안전화.
  3. `_buildZoneSelector` 가 `${entry.key}F` 대신 **`entry.value` (라벨)** 또는 약어("B1"/"B2")를 표시하도록 변경.
  4. (선택) 추후 백엔드에 "주차장 가능 구역 목록 조회" 엔드포인트가 생기면 동적 로딩으로 전환. 현재는 백엔드에 해당 엔드포인트 없음.
- **근거**:
  - 백엔드 컨트롤러: `ParkingController.getZoneSummary` (`@GetMapping("/zones/{zoneId}/spots")`).
  - 서비스: `ParkingServiceImpl.getZoneSummary` 는 zone 존재 시 주차면 0개여도 정상 응답 → "오류"가 아닌 "빈 데이터" 상태로 떨어짐.
  - V3 `zones` 시드: (1,'1층'), (2,'회의실A').
  - V5 `zones` 시드: (3,'2층')... (8,'지하1층').
  - V8 `zones` 시드: (9,'지하2층'), (10~14, 회의실/휴게실).
  - V5 `parking_spots` 시드: zone_id=8, 5개.
  - V8 `parking_spots` 시드: zone_id=8 추가 10개, zone_id=9 10개.
- **우선순위**: 상 (앱 핵심 기능 다운 상태)
- **출처 세션**: 2026-05-14 SmartOffice-app ↔ server 연결 점검.

---

## [2026-05-14] 토큰 만료(401) 자동 재발급이 LoginScreen 안에만 존재 — 다른 화면들은 401 즉시 실패

- **발생 맥락**: 동일 점검 중 백엔드 호출 코드 전반 검토.
- **문제**:
  - `LoginScreen._refreshAccessToken` / `apiRequest` 유틸은 잘 구현되어 있으나, **`recpit.dart`, `parking.dart`, `employee_page_card.dart` 등 다른 화면들은 이 유틸을 사용하지 않고** 직접 `http.get` 만 호출하고 401 을 단순 오류 메시지로 처리.
  - Access Token TTL 이 30분이므로, 로그인 후 30분이 지나면 거의 모든 페이지가 동시에 깨짐. 사용자는 "갑자기 다 안 됨" 으로 인지.
- **제안 내용**:
  1. **공통 API 클라이언트 모듈** 도입 — 예: `lib/core/api_client.dart` 에 `apiGet(path)` / `apiPost(path, body)` 노출. 내부에서 자동 401 재시도(refresh) + 만료 시 LoginScreen 푸시까지 일원화.
  2. 모든 페이지가 직접 `http` 패키지를 import 하지 않고 본 클라이언트를 통하도록 점진 마이그레이션.
  3. 토큰 저장소도 `SharedPreferences` 접근을 직접 흩뿌리지 말고 `TokenStorage` 클래스로 캡슐화.
- **우선순위**: 중 (사용자 체감 큰 회귀지만 단일 페이지 다운은 아님)
- **출처 세션**: 2026-05-14 SmartOffice-app ↔ server 연결 점검.

---

## [2026-05-14] baseUrl 하드코딩 (`http://10.0.2.2:8080`) — Android 에뮬레이터 외 환경 불가

- **발생 맥락**: 동일 점검.
- **문제**:
  - `LoginScreen.dart`, `recpit.dart`, `parking.dart` 등 다수 파일에 `static const String _baseUrl = 'http://10.0.2.2:8080';` 가 **각자 정의**되어 있음.
  - `10.0.2.2` 는 Android 에뮬레이터 전용(호스트 PC 루프백). iOS 시뮬레이터에서는 `127.0.0.1`, 실기기에서는 LAN IP(EC2) 필요.
  - 운영 배포 시 일괄 변경이 어려움 (검색 누락 위험).
- **제안 내용**:
  1. `lib/core/env.dart` 또는 `--dart-define` 빌드 인자로 baseUrl 일원화.
     ```dart
     class Env {
       static const String apiBaseUrl = String.fromEnvironment(
         'API_BASE_URL',
         defaultValue: 'http://10.0.2.2:8080',
       );
     }
     ```
  2. 플랫폼별 기본값을 두려면 `Platform.isIOS` 분기 또는 `defaultTargetPlatform` 분기 사용.
  3. 운영 배포 시 EC2 도메인(HTTPS) 으로 빌드 환경 변수로 주입.
- **우선순위**: 중
- **출처 세션**: 2026-05-14 SmartOffice-app ↔ server 연결 점검.

---

## [2026-05-14] 근태조회(check.dart)·회의실 예약·조명·온도 화면 백엔드 미연결 (mockData)

- **발생 맥락**: 동일 점검 중 lib 전 파일 grep 결과 백엔드 호출 0건 화면 발견.
- **현황**:
  - `lib/check.dart` (근태조회): `_generateMockData(month)` 가짜 데이터로 출/결근/지각/휴가 표시.
  - `lib/reservation.dart`, `lib/light.dart`, `lib/temp_control.dart`: `http` import 자체 없음 — UI/목업 단계.
- **백엔드 가용 엔드포인트 (이미 구현됨)**:
  - 근태: `GET /api/v1/attendance/me?year=&month=` 등 (`attendance` 도메인).
  - 예약: `reservation` 도메인 8개 API.
  - 전력/센서/제어: `power`, `sensor`, `control` 도메인.
- **제안 내용**:
  1. 우선순위 큰 순서로 (근태조회 → 회의실 예약 → 환경/제어) 백엔드 통합.
  2. 위 P2 의 공통 API 클라이언트 모듈을 먼저 도입한 뒤 각 화면을 마이그레이션하는 게 효율적.
- **우선순위**: 중 (현재 시연에는 mock 으로 동작하지만 실 서비스는 아님)
- **출처 세션**: 2026-05-14 SmartOffice-app ↔ server 연결 점검.

---

## [2026-05-14] (참고) /api/v1/users/me 와 사원증 화면은 정상 — 회귀 시 우선 비교 대상

- **상태**: 정상 동작 확인. `UserMeInfoResponse` 의 `name/position/department/employeeNumber/id` 필드와 앱 파싱 일치.
- **활용**: 향후 다른 화면에서 인증/응답 형식 회귀가 의심될 때 본 페이지를 기준점으로 사용. (`employee_page_card.dart` 86-118 행)
- **우선순위**: -
- **출처 세션**: 2026-05-14 SmartOffice-app ↔ server 연결 점검.
