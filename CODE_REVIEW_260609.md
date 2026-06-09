# SmartOffice-app 코드리뷰 (2026-06-09)

> 대상: `lib/` 전체 10개 파일 (약 4,474줄). READ 전용 분석 결과 문서.
> 상태관리 라이브러리 미사용 (순수 StatefulWidget + setState). 네트워킹은 `http` 패키지, 토큰은 `shared_preferences`.
> 금지문자(em/en-dash, 이모지, 중간점, 곡선따옴표) 미사용 원칙으로 작성.

---

## 1. 요약

- 전반적으로 화면별 단일 책임 구조는 명확하고, 최근 보강(`reservation.dart` 겹침 검사, `recpit.dart` 본인 급여 단건 호출, `parking.dart` zone 매핑)으로 핵심 정합성 이슈는 해소된 상태다.
- 다만 다음 구조적 문제가 남아 있다.
  1. **인증 보안**: 액세스/리프레시 토큰을 `shared_preferences` 평문 저장. `flutter_secure_storage` 권장.
  2. **토큰 자동 재발급 로직이 사실상 동작하지 않음**: `LoginScreen` 안에 401 -> refresh 재시도 인프라(`apiRequest`, `_refreshAccessToken`)가 구현돼 있으나 **어디서도 호출되지 않는 죽은 코드**다. 다른 화면들은 401 처리를 제각각(로그인 이동 / 에러 메시지 / 무시)으로 한다. 만료 시 UX가 일관되지 않음.
  3. **async gap 후 context/`setState` 사용**: 여러 화면에서 `await` 직후 `mounted` 확인 없이 `setState`/`Navigator`/`ScaffoldMessenger`를 호출. Flutter 공식 가이드 위반(lint `use_build_context_synchronously`).
  4. **base URL 8개 파일 하드코딩 중복**: 환경 분리 불가, 변경 시 누락 위험.
  5. **N+1 네트워크 호출**: 근태(일자별), 회의실 예약(방별), 급여(월별)에서 화면당 수~수십 건 병렬 GET. 타임아웃 부재와 결합 시 체감 지연/배터리 영향.
- 빌드 차단급(컴파일 에러) 이슈는 없음. 아래는 정확성/보안/유지보수 관점 지적.

### 심각도별 건수

- 상(High): 5건
- 중(Medium): 9건
- 하(Low): 8건

---

## 2. 발견사항 (심각도별)

### 2.1 상 (High)

#### H-1. 토큰을 `shared_preferences`에 평문 저장 (보안)
- 위치: `LoginScreen.dart:42-51,168-170`, `check.dart:78,132-133,150-151`, 그리고 토큰을 읽는 전 화면(`parking.dart:83`, `temp_control.dart:73`, `light.dart:65`, `reservation.dart:11`, `recpit.dart:46`, `check.dart:78`).
- 문제: `auth_token`, `refresh_token`을 `SharedPreferences`에 저장. Android는 앱 전용 영역이지만 루팅/백업 추출 시 평문 노출. 리프레시 토큰까지 평문으로 두는 것은 위험.
- 근거: Context7 `flutter_secure_storage` 공식 문서 - 토큰 등 민감정보는 Keychain(iOS) / AES + KeyStore(Android)로 암호화 저장 권장. `await storage.write(key: 'token', value: ...)` / `await storage.read(key: 'token')`.
- 권장수정: `flutter_secure_storage` 도입, 토큰 read/write/clear를 단일 `TokenStore` 클래스로 캡슐화. 비밀번호 텍스트필드는 그대로 두되 저장 계층만 교체.
- 우선순위: 상

#### H-2. 401 자동 재발급 인프라가 죽은 코드 + 화면별 인증만료 처리 불일치
- 위치: `LoginScreen.dart:59-115` (`_refreshAccessToken`, `apiRequest`).
- 문제: `apiRequest`/`_refreshAccessToken`/`_getAccessToken`/`_saveAccessToken`/`_clearTokens`가 정의돼 있으나 **호출처가 전혀 없다**(grep 확인). 실제 화면들은 각자 다르게 처리한다.
  - `check.dart`: 401/403 -> 로그인 이동.
  - `recpit.dart`: 401 -> 에러 메시지만 표시(자동 재발급 없음).
  - `parking.dart`/`temp_control.dart`/`light.dart`/`reservation.dart`: 401을 일반 실패로 처리하거나 무시. refresh token 사용 안 함.
- 결과: 액세스 토큰이 만료되면 refresh token이 있어도 재발급되지 않고, 화면마다 동작이 달라진다(어떤 화면은 "서버 연결 불가", 어떤 화면은 로그인 화면).
- 권장수정: 인증 로직을 공용 `ApiClient`로 추출(아래 M-1 참고)하고 모든 화면이 그것을 경유하도록. 또는 죽은 코드 제거 후 단일 정책 적용.
- 우선순위: 상

#### H-3. `LoginScreen._login` async gap 후 context 사용
- 위치: `LoginScreen.dart:159-176`.
- 문제: `if (!mounted) return;`(159행)은 첫 `await http.post` 직후에만 있다. 이후 168행 `await SharedPreferences.getInstance()` + `await prefs.setString` 두 번의 async gap을 더 거친 뒤, mounted 재확인 없이 173행 `Navigator.pushReplacement(context, ...)`를 호출한다.
- 근거: Context7 Flutter 공식 - "When a BuildContext is used from a StatefulWidget, the mounted property must be checked after an asynchronous gap." (`if (!context.mounted) return;`).
- 권장수정: 토큰 저장 `await` 이후 `if (!mounted) return;` 재확인 후 네비게이트.
- 우선순위: 상

#### H-4. `check.dart._fetchMyProfileData` 다중 async gap 후 mounted 미확인 setState
- 위치: `check.dart:73-123`.
- 문제: 함수 어디에도 `mounted` 확인이 없다. `await http.get` 이후 `setState`(106행) 및 `_goToLogin`(114,117,121행 -> `Navigator`)을 호출. 위젯이 dispose된 뒤 응답이 도착하면 "setState() called after dispose()" 예외 위험. 특히 `initState`에서 시작되고 사용자가 즉시 뒤로 가는 경우 재현 가능.
- 권장수정: `await` 직후 `if (!mounted) return;` 추가. `_goToLogin` 진입 전에도 mounted 보장(이미 `_goToLogin` 내부에 mounted 가드 있음 -> setState만 추가 보호 필요).
- 우선순위: 상

#### H-5. `light.dart` 옵티미스틱 토글의 동시 클릭/연타 경쟁 + 미인증 분기 context 사용
- 위치: `light.dart:68-141`.
- 문제:
  1. `_toggleLight`는 먼저 상태를 뒤집고(80-83행) 전송한다. 같은 구역을 빠르게 연타하면 `isSending` 가드가 UI 버튼(365행 `onTap: selectedZone.isSending ? null`)에만 걸려 있어, GridView의 다른 셀을 통한 재진입이나 빠른 탭 사이 경쟁으로 상태와 서버가 어긋날 수 있다.
  2. 72행 `ScaffoldMessenger.of(context)`는 첫 `await`(86행) 이전이라 안전하지만, deviceId가 항상 non-null인 시드 구성상 71-76행 분기는 **도달 불가 죽은 코드**.
- 권장수정: 전송 중 해당 인덱스 입력 자체를 잠그고(별도 in-flight 플래그), 응답 성공 시에만 최종 상태 확정(서버 echo 신뢰) 또는 실패 시 롤백 일관화. 도달 불가 분기 제거.
- 우선순위: 상(경쟁 조건), 분기 제거는 중.

---

### 2.2 중 (Medium)

#### M-1. base URL 8개 파일 하드코딩 중복
- 위치: `LoginScreen.dart:19`, `check.dart:87,138`, `parking.dart:16`, `temp_control.dart:34`, `light.dart:30`, `reservation.dart:7`, `recpit.dart:14`, `check.dart:36`. 값은 모두 `https://api.sjparkx1129.com`. `check.dart`는 상수와 별개로 87/138행에 URL을 통째로 다시 하드코딩(상수 미사용)까지 함.
- 문제: 환경(dev/stg/prod) 분리 불가, 변경 시 누락 위험. 인증 헤더 조립도 화면마다 중복.
- 권장수정: `ApiConfig.baseUrl` 단일 상수 + 공용 `ApiClient`(헤더/타임아웃/401 처리 포함). `--dart-define`로 환경 주입 권장.
- 우선순위: 중

#### M-2. HTTP 호출에 타임아웃 부재
- 위치: 모든 `http.get/post/delete` 호출.
- 문제: `.timeout(...)` 미설정. 서버 지연/네트워크 단절 시 무한 대기 가능. 특히 N+1 병렬 호출(M-3)과 결합되면 로딩 스피너가 장시간 유지.
- 권장수정: `http.get(...).timeout(const Duration(seconds: 10))` + `TimeoutException` 처리.
- 우선순위: 중

#### M-3. N+1 네트워크 호출 패턴
- 위치:
  - `check.dart:230-251` - 한 달 일자별 `/attendance/me/daily` 개별 GET(평일 수만큼, 최대 ~23건).
  - `reservation.dart:146-174` - 회의실 목록 각 방마다 `/zones/{id}/reservations` GET.
  - `recpit.dart:64-77` - 최근 6개월 `/salary/records/me` 6건.
  - `parking.dart:131-164` - zone 수만큼 `/parking/zones/{id}/spots` 반복.
- 문제: 화면 진입마다 다건 호출. 서버에 월간/목록 배치 엔드포인트가 있으면 1회로 축약 가능. 백엔드 협의 대상(읽기 전용 레포이므로 제안만).
- 권장수정: 백엔드에 월별 일괄 근태 / 다중 zone 예약 조회 엔드포인트 신설 제안. 클라이언트는 `Future.wait` 유지하되 타임아웃 필수.
- 우선순위: 중

#### M-4. `temp_control.dart` 타입 캐스팅 런타임 예외 위험
- 위치: `temp_control.dart:100`.
- 문제: `final int totalCount = data['totalCount'] as int;` - 서버가 숫자를 `double`이나 문자열로 주거나 키 누락 시 `as int`가 즉시 throw. 같은 파일 99행 `data['sensorDataList']`도 null/형변환 가드 없음(`as Map`/리스트 단정). try-catch가 바깥에 있어 화면이 통째로 에러로 빠짐.
- 권장수정: `(data['totalCount'] as num?)?.toInt() ?? 0`, 리스트는 `as List<dynamic>? ?? []`.
- 우선순위: 중

#### M-5. `recpit.dart` 금액 필드 무가드 캐스팅
- 위치: `recpit.dart:208-210,416-419,453,486`.
- 문제: `current['baseSalary'] ?? 0`는 null만 막고, 값이 `double`/문자열이면 이후 `_formatCurrency(int amount)` 시그니처와 충돌. `_buildDetailSection`의 `item['value'] as int`(418행)는 서버가 `double` 반환 시 throw.
- 권장수정: `(current['baseSalary'] as num?)?.toInt() ?? 0` 형태로 통일.
- 우선순위: 중

#### M-6. `parking.dart` 자동 새로고침 중 setState 누적/주석 불일치
- 위치: `parking.dart:64`(주석 "5초마다"인데 실제 `Duration(seconds: 10)`), `131-164` `_fetchAllZoneSummary`가 zone마다 setState 호출(루프 내 setState로 다중 리빌드).
- 문제: 주석과 코드 불일치. 루프 내 zone별 setState로 동일 프레임에 N회 리빌드(비효율). 타이머는 dispose에서 정리되므로 누수는 없음.
- 권장수정: 결과를 로컬 맵에 모은 뒤 1회 setState. 주석 수정.
- 우선순위: 중

#### M-7. 이미지 선택 결과가 서버에 저장되지 않음(휘발성)
- 위치: `check.dart:156-170`.
- 문제: 사원증 사진을 갤러리에서 골라 `_employeeImage`에만 보관 -> 앱 재시작/화면 재진입 시 사라짐. 서버 업로드/프로필 연동 없음. 또한 `Permission.photos`만 요청하는데 Android 13+는 `READ_MEDIA_IMAGES`, 그 이하/카메라 경로에 따라 권한 분기 필요.
- 권장수정: 의도가 영구 저장이면 업로드 API 연동. 단순 미리보기면 그 취지를 명확히. 권한은 플랫폼/SDK 버전 분기.
- 우선순위: 중

#### M-8. 응답 래퍼(`code == 'success'`) 가정 불일치
- 위치: 성공 판정이 화면마다 다름.
  - `check.dart:104`, `parking.dart:100`, `temp_control.dart:98`, `recpit.dart:95` - `json['code'] == 'success'` 확인.
  - `reservation.dart:91-105,432-441` - statusCode 200만 보고 `body['data']` 직접 사용(`code` 미확인).
  - `LoginScreen.dart:161` - statusCode 200만.
- 문제: 공통 래퍼 `ApiResponse<T>{code,message,data}` 처리 규약이 화면별로 제각각. `code`가 success가 아니어도 200이면 통과하는 화면 존재.
- 권장수정: 공용 파서로 `code` 검증 일원화.
- 우선순위: 중

#### M-9. `reservation.dart` 예약 겹침 검사가 클라이언트 단독 신뢰
- 위치: `reservation.dart:569-587`.
- 문제: 겹침 검사는 좋으나 `_existingSlots`는 진입 시점 스냅샷. 제출 직전 타 사용자가 예약하면 클라이언트는 통과시키고 서버 거절에 의존. 서버 거절 메시지는 표시되므로 치명적이진 않음. 또한 과거 시각 시작 방지 검증 없음(오늘 날짜에 이미 지난 시간 선택 가능).
- 권장수정: 제출 직전 재조회 또는 서버 에러를 1차 신뢰. 시작 시각이 현재 이후인지 검증 추가.
- 우선순위: 중

---

### 2.3 하 (Low)

#### L-1. 파일명 PascalCase (`LoginScreen.dart`)
- 위치: `lib/LoginScreen.dart`.
- 문제: Dart/Flutter 컨벤션상 파일명은 `lower_snake_case`(`login_screen.dart`). 나머지 파일은 대체로 snake_case(`employee_page_card.dart`, `temp_control.dart`)라 일관성도 깨짐. lint `file_names` 대상.
- 권장수정: `login_screen.dart`로 변경 + import 경로 갱신.
- 우선순위: 하

#### L-2. `recpit.dart` 파일명 오타
- 위치: `lib/recpit.dart` (recpit -> 의도상 receipt).
- 권장수정: `receipt.dart` 또는 도메인에 맞게 `salary.dart`.
- 우선순위: 하

#### L-3. 주석/식별자에 이모지 사용
- 위치: `main.dart:2,3,7,8,11,17,33,34`, `menu.dart:6,110,122`.
- 문제: 프로젝트 전역 규칙(이모지 금지)에 위배. 식별자 영어/주석 한국어 원칙은 대체로 지켜지나 이모지가 다수.
- 권장수정: 이모지 제거.
- 우선순위: 하

#### L-4. 죽은 코드 / 미사용 위젯
- 위치:
  - `LoginScreen.dart:32-115` - `apiRequest`, `_refreshAccessToken`, `_getAccessToken`, `_saveAccessToken`, `_clearTokens`, `_getRefreshToken` 전부 미호출(H-2 참조).
  - `recpit.dart:384-409` - `_buildGridItem` 미사용.
  - `recpit.dart`의 `_buildDetailSection(..., isNegative)` 공제 분기(`isNegative == true`)는 호출부(357행)에서 항상 `false`라 공제 UI는 사용되지 않음.
  - `light.dart:71-76` - deviceId 항상 non-null이라 도달 불가 분기.
- 권장수정: 미사용 코드 제거 또는 실제 연결.
- 우선순위: 하

#### L-5. `withOpacity` 사용(신규 Flutter에서 deprecated)
- 위치: `check.dart`(4곳), `employee_page_card.dart`(2곳), `light.dart`(2곳), `recpit.dart`(2곳), `reservation.dart`(1곳), `temp_control.dart`(1곳).
- 문제: Flutter 3.27+ 에서 `Color.withOpacity`는 deprecated, `withValues(alpha: ...)` 권장. SDK `^3.10.7` 환경에서 경고 발생 가능.
- 권장수정: `color.withValues(alpha: 0.05)` 형태로 교체.
- 우선순위: 하

#### L-6. `const` 생성자 키 구식 패턴
- 위치: `LoginScreen.dart:8`, `main.dart:22` - `const X({Key? key}) : super(key: key)`. 나머지 파일은 `super.key` 신규 문법 사용. 일관성 결여(lint `use_super_parameters`).
- 권장수정: `const X({super.key})`.
- 우선순위: 하

#### L-7. 매직 컬러/문자열 산재, 디자인 토큰 부재
- 위치: 전 파일. `Color(0xFFF2F4F6)`, `Color.fromARGB(255, 248, 193, 43)`(브랜드 옐로) 등 동일 색이 파일마다 재선언. 메뉴 분기는 한국어 라벨 문자열 비교(`menu.dart:92-130`)로 라우팅 -> 오타에 취약.
- 권장수정: `AppColors`/`AppStrings` 상수 또는 `ThemeExtension`. 메뉴 라우팅은 enum/식별자 기반으로.
- 우선순위: 하

#### L-8. `temp_control.dart` sensorType 매핑에 CO2 파싱하나 UI 미표시
- 위치: `temp_control.dart:13,144,326-364`.
- 문제: 모델/파서는 `co2`를 읽지만 `_buildSensorCard`는 온도/습도만 출력. CO2는 수집 후 미사용(불완전 기능 또는 잔여물).
- 권장수정: CO2 표시 추가 또는 모델에서 제거.
- 우선순위: 하

---

## 3. Context7 근거 요약

- **Flutter 공식(`/flutter/website`) - async gap 후 context**: "When a BuildContext is used from a StatefulWidget, the mounted property must be checked after an asynchronous gap." 예: `final result = await Navigator.push(...); if (!context.mounted) return;`. (H-3, H-4 근거)
- **Flutter 공식 - build 중 부수효과 금지**: build 메서드 안에서 `showDialog`/`setState` 호출 시 "setState() or markNeedsBuild() called during build" 에러. 본 앱은 build 중 직접 호출은 없으나(양호), setState 트리거는 이벤트/await 콜백 내에서만 수행하는 원칙 재확인.
- **flutter_secure_storage(`/juliansteenbakker/flutter_secure_storage`) - 민감정보 저장**: 토큰은 Keychain(iOS)/AES + KeyStore(Android)로 암호화 저장 권장. `await storage.write(key:'token', value:...)` / `await storage.read(key:'token')`. iOS는 `useSecureEnclave`, Android는 `AndroidOptions.biometric(...)` 옵션 제공. (H-1 근거 - 현재 `shared_preferences` 평문 저장 대체)

---

## 4. 호출 엔드포인트 인벤토리 (app -> server)

기본 인증: 로그인/리프레시 제외 모든 호출에 `Authorization: Bearer <auth_token>`(SharedPreferences) 첨부. base URL은 전 파일 `https://api.sjparkx1129.com` 하드코딩. 사용자 권한 가정: 모두 USER 권한, 본인 데이터 한정(`/me` 경로 또는 본인 식별 의존). 관리자 전용 엔드포인트 호출은 없음(과거 급여 ADMIN 호출은 `/salary/records/me`로 교체 완료).

| METHOD | 경로 | 호출 위치(파일:라인) | 인증 | 기대 응답 구조 |
|--------|------|----------------------|------|----------------|
| POST | `/api/v1/auth/login` | `LoginScreen.dart:150-157` | 없음(공개) | `data.accessToken`, `data.refreshToken` (statusCode 200 판정) |
| POST | `/api/v1/auth/refresh` | `LoginScreen.dart:64-68` (죽은 코드, 미호출) | refreshToken in body | `data.accessToken` |
| POST | `/api/v1/auth/logout` | `check.dart:137-144` | Bearer + body `{refreshToken}` | 응답 무시(성공/실패 모두 로컬 토큰 삭제) |
| GET | `/api/v1/users/me` | `check.dart:86-92`; `reservation.dart:386-392` | Bearer | `code=='success'`, `data{name,position,department,employeeNumber}` (reservation은 `data.name`만, code 미확인) |
| GET | `/api/v1/attendance/me/monthly?month=YYYY-MM` | `check.dart:212-215` | Bearer | `data{absentCount,earlyLeaveCount}` |
| GET | `/api/v1/attendance/me/daily?date=YYYY-MM-DD` | `check.dart:146-149` | Bearer | `data{checkIn,checkOut,attendanceStatus}` (일자별 N건 호출) |
| GET | `/api/v1/salary/records/me?year=Y&month=M` | `recpit.dart:66-75` | Bearer | `code=='success'`, `data{year,month,baseSalary,overtimePay,totalPay,status}` (최근 6개월 병렬) |
| GET | `/api/v1/parking/zones/{zoneId}/spots` | `parking.dart:87` (선택 구역), `parking.dart:138-144` (전 zone 요약) | Bearer | `code=='success'`, `data{zoneName,totalSpots,occupiedSpots,availableSpots,spots[]{spotNumber,spotType,spotStatus,occupied}}` |
| GET | `/api/v1/sensors/latest?zoneId={id}` | `temp_control.dart:93` | Bearer | `code=='success'`, `data{totalCount,sensorDataList[]{sensorType,value,timestamp}}` (zone별 병렬) |
| POST | `/api/v1/controls` | `light.dart:107-114` | Bearer + body | body `{zoneId,deviceId,command:'LIGHT',value:'ON'|'OFF'}`, statusCode 200 판정, 실패 시 `message` |
| GET | `/api/v1/zones/reservable` | `reservation.dart:81-87` | Bearer | `data[]{id,name,zoneType}` (zoneType AREA/ROOM 필터) |
| GET | `/api/v1/zones/{zoneId}/reservations?date=YYYY-MM-DD` | `reservation.dart:149-157` (목록 화면), `reservation.dart:420-428` (상세 화면) | Bearer | `data.reservationList[]{id,startTime,endTime,status}` |
| POST | `/api/v1/reservations` | `reservation.dart:608-615` | Bearer + body | body `{zoneId,startTime(ISO),endTime(ISO),purpose?}`, statusCode 200/201 판정, 실패 시 `message` |
| DELETE | `/api/v1/reservations/{reservationId}` | `reservation.dart:837-843` | Bearer | statusCode 200 판정, 실패 시 `message` |

### 정합성 메모
- `code=='success'` 래퍼 검증 일관성 없음: parking/temp_control/recpit/check(users/me)는 검증, reservation/login은 statusCode만 신뢰(M-8).
- `auth/refresh`는 코드에 존재하나 실제 호출 경로 없음 -> 토큰 만료 시 자동 재발급 미동작(H-2).
- 토큰 키: `auth_token`(access), `refresh_token`(refresh) 두 개를 SharedPreferences에 평문 저장(H-1).
- 시드 의존 하드코딩 매핑: 조명/온습도 zone-device 맵(`light.dart:33-43`, `temp_control.dart:37-47`), 주차 zone 맵(`parking.dart:24-27`)이 백엔드 시드값에 강결합. 시드 변경 시 앱 수정 필요.
