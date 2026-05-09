import 'package:flutter/material.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class AttendanceRecord {
  final String id;
  final String date;
  final String dayOfWeek;
  final String? checkIn;
  final String? checkOut;
  final String status;

  AttendanceRecord({
    required this.id,
    required this.date,
    required this.dayOfWeek,
    this.checkIn,
    this.checkOut,
    required this.status,
  });
}

class _AttendancePageState extends State<AttendancePage> {
  final int currentYear = 2026;
  late int selectedMonth;
  List<AttendanceRecord> mockData = [];
  List<int> months = [5, 4, 3, 2, 1];

  @override
  void initState() {
    super.initState();
    // 접속한 현재 달 기준 설정
    selectedMonth = DateTime.now().month;
    _generateMockData(selectedMonth);
  }

  // 달을 바꿀때 마다 데이타를 생성하는 로직
  void _generateMockData(int month) {
    final records = <AttendanceRecord>[];
    final days = ['일', '월', '화', '수', '목', '금', '토'];
    final today = DateTime.now();
    final currentMonth = today.month;
    final currentDate = today.day;

    // 선택한 달의 마지막 날 구하기
    int lastDay = DateTime(currentYear, month + 1, 0).day;
    int startDay = lastDay;

    // 만약 선택한 달이 이번 달이라면 오늘 날짜까지만 역순으로 루프
    if (month == currentMonth) {
      startDay = currentDate;
    }

    // startDay 부터 1일까지 역순(-)으로 뷰를 만듬
    for (int d = startDay; d >= 1; d--) {
      final dateObj = DateTime(currentYear, month, d);
      final dayOfWeek = days[dateObj.weekday % 7];
      final isWeekend = dateObj.weekday == 6 || dateObj.weekday == 7;
      final isToday = month == currentMonth && d == currentDate;

      final pseudoRandom = (month * 31 + d) % 100;

      String? checkIn;
      String? checkOut;
      String status = '미등록';

      // (가상 데이터 로직)
      if (isWeekend) {
        status = '미등록';
      } else if (pseudoRandom < 10) {
        status = '휴가';
      } else if (pseudoRandom < 15 && !isToday) {
        status = '결근';
      } else if (pseudoRandom < 30) {
        status = '지각';
        checkIn = '09:${(pseudoRandom % 30) + 10}';
        checkOut = isToday ? null : '17:${(pseudoRandom % 30) + 30}';
      } else {
        status = '출근';
        checkIn = '08:${(pseudoRandom % 30) + 10}';
        checkOut = isToday ? null : '17:${(pseudoRandom % 30) + 30}';
      }

      records.add(
        AttendanceRecord(
          id: 'rc_${month}_$d',
          date: '$month/$d',
          dayOfWeek: dayOfWeek,
          checkIn: checkIn,
          checkOut: checkOut,
          status: status,
        ),
      );
    }

    setState(() {
      mockData = records;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 뷰 생성시 리스트를 기반으로 상단 요약 Card 데이타(출근/결근/휴가 일수) 연산 처리
    int worked = mockData
        .where((r) => r.status == '출근' || r.status == '지각')
        .length;
    int absent = mockData.where((r) => r.status == '결근').length;
    int leave = mockData.where((r) => r.status == '휴가').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6), // 토스 라이트블루/그레이 배경색
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F4F6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF191F28),
            size: 20,
          ),
          // 뒤로 가기 동작 연동
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '근태 조회',
          style: TextStyle(
            color: Color(0xFF191F28),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 월 선택 필터 영역
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: months.map((m) {
                final isActive = selectedMonth == m;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        selectedMonth = m;
                        _generateMockData(m); // 달 클릭 시 데이터 재생성
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFFBBF24)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: isActive
                            ? null
                            : Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        '${m}월',
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : const Color(0xFF8B95A1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                // 동적 요약 카드 영역
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '2026년 ${selectedMonth}월 근태 요약',
                        style: const TextStyle(
                          color: Color(0xFF8B95A1),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem('출근', '${worked}d', true), // 출근자 현황 노출
                          Container(
                            width: 1,
                            height: 38,
                            color: Colors.grey.shade100,
                          ),
                          _buildStatItem('결근', '${absent}d', false),
                          Container(
                            width: 1,
                            height: 38,
                            color: Colors.grey.shade100,
                          ),
                          _buildStatItem('사용휴가', '${leave}d', false),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                const Text(
                  '근태 내역',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF191F28),
                  ),
                ),
                const SizedBox(height: 16),

                // 근태 리스트 (역순 출력)
                ...mockData.map((record) {
                  final recordDay = int.parse(record.date.split('/')[1]);
                  final isToday =
                      selectedMonth == DateTime.now().month &&
                      recordDay == DateTime.now().day;
                  return _buildRecordCard(record, isToday);
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 상단 Card 통계 아이템 빌드 위젯
  Widget _buildStatItem(String label, String value, bool highlight) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8B95A1),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: highlight
                ? const Color(0xFFFBBF24)
                : const Color(0xFF191F28),
            fontSize: 19,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  // 단일 근태 내역 카드 형태 빌드 위젯
  Widget _buildRecordCard(AttendanceRecord record, bool isToday) {
    final isWeekend = record.dayOfWeek == '토' || record.dayOfWeek == '일';

    Color badgeBgColor;
    Color badgeTextColor;

    // 토스 앱 특유의 Badge 라벨 컬러 스타일 매칭
    switch (record.status) {
      case '출근':
        badgeBgColor = const Color(0xFFE8F3FF);
        badgeTextColor = const Color(0xFF1B64DA); // Blue
        break;
      case '지각':
        badgeBgColor = const Color(0xFFFFF4E6);
        badgeTextColor = const Color(0xFFF9A825); // Yellow / Orange
        break;
      case '결근':
        badgeBgColor = const Color(0xFFFFECEF);
        badgeTextColor = const Color(0xFFF04452); // Red
        break;
      case '휴가':
        badgeBgColor = const Color(0xFFF2F4F6);
        badgeTextColor = const Color(0xFF8B95A1);
        break;
      default:
        badgeBgColor = const Color(0xFFF2F4F6);
        badgeTextColor = const Color(0xFFB0B8C1);
    }

    final dateParts = record.date.split('/');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isToday
            ? const Color(0xFFFFFAF0).withOpacity(0.8)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isToday
            ? Border.all(
                color: const Color(0xFFFBBF24).withOpacity(0.4),
                width: 2,
              )
            : null,
        boxShadow: [
          if (!isToday)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  // 일자 표시 동그란 컨테이너
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isWeekend
                          ? Colors.red.shade50
                          : const Color(0xFFF2F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          record.dayOfWeek,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isWeekend
                                ? Colors.red.shade400
                                : const Color(0xFF8B95A1),
                          ),
                        ),
                        Text(
                          dateParts[1],
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isWeekend
                                ? Colors.red.shade500
                                : const Color(0xFF191F28),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isToday)
                    // 당일 일자에 하이라이트 dot 노출
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.checkIn != null
                        ? '${record.checkIn} ~ ${record.checkOut ?? '진행중'}'
                        : (isWeekend ? '주말' : '기록 없음'),
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF191F28),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.status == '출근'
                        ? '정상 출근'
                        : (record.status == '미등록' ? '-' : record.status),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8B95A1),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // 우측 Badge 컨테이너
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              record.status,
              style: TextStyle(
                color: badgeTextColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
