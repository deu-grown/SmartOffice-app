import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class AttendanceRecord {
  final String date;
  final String dayOfWeek;
  final String? checkIn;
  final String? checkOut;
  final String status;

  AttendanceRecord({
    required this.date,
    required this.dayOfWeek,
    this.checkIn,
    this.checkOut,
    required this.status,
  });
}

class _AttendancePageState extends State<AttendancePage> {
  static const String _baseUrl = 'http://10.0.2.2:8080';

  final int _currentYear = DateTime.now().year;
  late int _selectedMonth;
  late List<int> _months;

  List<AttendanceRecord> _records = [];
  int _workedCount = 0;
  int _absentCount = 0;
  int _earlyLeaveCount = 0;

  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now().month;
    // 현재 달 기준 최근 5개월
    _months = List.generate(5, (i) {
      int m = DateTime.now().month - i;
      if (m <= 0) m += 12;
      return m;
    });
    _fetchAttendance(_selectedMonth);
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  String _mapStatus(String raw) {
    switch (raw) {
      case 'NORMAL':
        return '출근';
      case 'LATE':
        return '지각';
      case 'EARLY_LEAVE':
        return '조기퇴근';
      case 'ABSENT':
        return '결근';
      default:
        return '미등록';
    }
  }

  String? _formatTime(String? iso) {
    if (iso == null) return null;
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }

  Future<AttendanceRecord> _fetchDailyRecord(
    String dateStr,
    String dayOfWeek,
    int month,
    int day,
    Map<String, String> headers,
  ) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/v1/attendance/me/daily?date=$dateStr'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        final data = body['data'];
        if (data != null) {
          return AttendanceRecord(
            date: '$month/$day',
            dayOfWeek: dayOfWeek,
            checkIn: _formatTime(data['checkIn'] as String?),
            checkOut: _formatTime(data['checkOut'] as String?),
            status: _mapStatus(data['attendanceStatus'] as String? ?? ''),
          );
        }
      }
    } catch (_) {}

    return AttendanceRecord(
      date: '$month/$day',
      dayOfWeek: dayOfWeek,
      status: '미등록',
    );
  }

  Future<void> _fetchAttendance(int month) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _records = [];
    });

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = '로그인이 필요합니다.';
          _isLoading = false;
        });
        return;
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final today = DateTime.now();
      final lastDay = DateTime(_currentYear, month + 1, 0).day;
      final endDay =
          (month == today.month && _currentYear == today.year)
              ? today.day
              : lastDay;

      // 1. 월별 요약 조회
      final monthStr =
          '$_currentYear-${month.toString().padLeft(2, '0')}';
      int absentCount = 0;
      int earlyLeaveCount = 0;

      final monthRes = await http.get(
        Uri.parse('$_baseUrl/api/v1/attendance/me/monthly?month=$monthStr'),
        headers: headers,
      );
      if (monthRes.statusCode == 200) {
        final body = jsonDecode(utf8.decode(monthRes.bodyBytes));
        final data = body['data'];
        if (data != null) {
          absentCount = data['absentCount'] as int? ?? 0;
          earlyLeaveCount = data['earlyLeaveCount'] as int? ?? 0;
        }
      }

      // 2. 일별 근태 병렬 조회
      final dayNames = ['일', '월', '화', '수', '목', '금', '토'];
      final futures = <Future<AttendanceRecord>>[];

      for (int d = 1; d <= endDay; d++) {
        final dateObj = DateTime(_currentYear, month, d);
        final dayOfWeek = dayNames[dateObj.weekday % 7];
        final isWeekend = dateObj.weekday == 6 || dateObj.weekday == 7;

        if (isWeekend) {
          futures.add(Future.value(AttendanceRecord(
            date: '$month/$d',
            dayOfWeek: dayOfWeek,
            status: '미등록',
          )));
        } else {
          final dateStr =
              '$_currentYear-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
          futures.add(
            _fetchDailyRecord(dateStr, dayOfWeek, month, d, headers),
          );
        }
      }

      final results = await Future.wait(futures);
      final workedCount = results
          .where((r) => r.status == '출근' || r.status == '지각')
          .length;

      if (mounted) {
        setState(() {
          _records = results.reversed.toList();
          _workedCount = workedCount;
          _absentCount = absentCount;
          _earlyLeaveCount = earlyLeaveCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '서버에 연결할 수 없습니다.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F4F6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF191F28),
            size: 20,
          ),
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
          // 월 선택 필터
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: _months.map((m) {
                final isActive = _selectedMonth == m;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () {
                      if (_selectedMonth == m) return;
                      setState(() => _selectedMonth = m);
                      _fetchAttendance(m);
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
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFBBF24),
                    ),
                  )
                : _errorMessage.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFF8B95A1),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Color(0xFF8B95A1)),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => _fetchAttendance(_selectedMonth),
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    children: [
                      // 요약 카드
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
                              '$_currentYear년 ${_selectedMonth}월 근태 요약',
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
                                _buildStatItem('출근', '${_workedCount}d', true),
                                Container(
                                  width: 1,
                                  height: 38,
                                  color: Colors.grey.shade100,
                                ),
                                _buildStatItem('결근', '${_absentCount}d', false),
                                Container(
                                  width: 1,
                                  height: 38,
                                  color: Colors.grey.shade100,
                                ),
                                _buildStatItem('조기퇴근', '${_earlyLeaveCount}d', false),
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

                      ..._records.map((record) {
                        final day = int.parse(record.date.split('/')[1]);
                        final isToday =
                            _selectedMonth == DateTime.now().month &&
                            _currentYear == DateTime.now().year &&
                            day == DateTime.now().day;
                        return _buildRecordCard(record, isToday);
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildRecordCard(AttendanceRecord record, bool isToday) {
    final isWeekend =
        record.dayOfWeek == '토' || record.dayOfWeek == '일';

    Color badgeBgColor;
    Color badgeTextColor;

    switch (record.status) {
      case '출근':
        badgeBgColor = const Color(0xFFE8F3FF);
        badgeTextColor = const Color(0xFF1B64DA);
        break;
      case '지각':
        badgeBgColor = const Color(0xFFFFF4E6);
        badgeTextColor = const Color(0xFFF9A825);
        break;
      case '결근':
        badgeBgColor = const Color(0xFFFFECEF);
        badgeTextColor = const Color(0xFFF04452);
        break;
      case '조기퇴근':
        badgeBgColor = const Color(0xFFFFF4E6);
        badgeTextColor = const Color(0xFFE65100);
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
