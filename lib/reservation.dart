import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _baseUrl = 'https://api.sjparkx1129.com';

Future<String?> _getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('auth_token');
}

// --- 데이터 모델 ---
class ZoneRoom {
  final int id;
  final String name;

  ZoneRoom({required this.id, required this.name});
}

class ReservationSlot {
  final int id;
  final String startTime;
  final String endTime;
  final String status;

  ReservationSlot({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  factory ReservationSlot.fromJson(Map<String, dynamic> json) {
    return ReservationSlot(
      id: (json['id'] as num).toInt(),
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      status: json['status'] as String? ?? '',
    );
  }
}

// --- 1. 회의실 목록 화면 ---
class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  List<ZoneRoom> _rooms = [];
  Map<int, List<String>> _roomTimeSlots = {};
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchZones();
  }

  Future<void> _fetchZones() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
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

      final res = await http.get(
        Uri.parse('$_baseUrl/api/v1/zones/reservable'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        final List<dynamic> data = body['data'] ?? [];
        final rooms = data
            .where((z) {
              final type = z['zoneType'] as String? ?? '';
              return type == 'AREA' || type == 'ROOM';
            })
            .map(
              (z) => ZoneRoom(
                id: z['id'] as int,
                name: z['name'] as String? ?? '구역 ${z['id']}',
              ),
            )
            .toList();

        setState(() {
          _rooms = rooms;
          _isLoading = false;
        });

        _fetchTodayBookedRooms(rooms, token);
      } else {
        setState(() {
          _errorMessage = '구역 정보를 불러올 수 없습니다. (${res.statusCode})';
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

  String _toHHmm(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _fetchTodayBookedRooms(List<ZoneRoom> rooms, String token) async {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final entries = await Future.wait(
      rooms.map((room) async {
        try {
          final res = await http.get(
            Uri.parse('$_baseUrl/api/v1/zones/${room.id}/reservations?date=$dateStr'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          if (res.statusCode == 200) {
            final body = jsonDecode(utf8.decode(res.bodyBytes));
            final data = body['data'];
            final List<dynamic> list = data['reservationList'] ?? [];
            final slots = list
                .where((e) => (e['status'] as String? ?? '') != 'CANCELLED')
                .map((e) => '${_toHHmm(e['startTime'] as String)}-${_toHHmm(e['endTime'] as String)}')
                .toList();
            if (slots.isNotEmpty) return MapEntry(room.id, slots);
          }
        } catch (_) {}
        return null;
      }),
    );

    if (mounted) {
      setState(() {
        _roomTimeSlots = Map.fromEntries(
          entries.whereType<MapEntry<int, List<String>>>(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '회의실 예약',
          style: TextStyle(
            color: Color(0xFF191F28),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF191F28)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4E5968)),
            onPressed: _fetchZones,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4E5968)),
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
                    style: const TextStyle(
                      color: Color(0xFF8B95A1),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _fetchZones,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            )
          : _rooms.isEmpty
          ? const Center(
              child: Text(
                '예약 가능한 회의실이 없습니다.',
                style: TextStyle(color: Color(0xFF8B95A1)),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: _rooms.length,
              itemBuilder: (context, index) => _buildRoomCard(
                _rooms[index],
                _roomTimeSlots[_rooms[index].id],
              ),
            ),
    );
  }

  Widget _buildRoomCard(ZoneRoom room, List<String>? slots) {
    final isBooked = slots != null && slots.isNotEmpty;
    final cardColor = isBooked ? const Color(0xFFFFF0F0) : Colors.white;
    final iconColor = isBooked ? const Color(0xFFF04452) : const Color(0xFF3182F6);
    final badgeColor = isBooked ? const Color(0xFFFFE0E3) : const Color(0xFFE8F3FF);
    final badgeTextColor = isBooked ? const Color(0xFFF04452) : const Color(0xFF3182F6);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReservationDetailScreen(room: room),
          ),
        ).then((_) => _fetchZones());
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.meeting_room_outlined,
              size: 36,
              color: iconColor,
            ),
            const SizedBox(height: 12),
            Text(
              room.name,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333D4B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: isBooked
                  ? Column(
                      children: slots!
                          .map(
                            (s) => Text(
                              s,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: badgeTextColor,
                              ),
                            ),
                          )
                          .toList(),
                    )
                  : Text(
                      '예약하기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: badgeTextColor,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 2. 예약 상세 화면 ---
class ReservationDetailScreen extends StatefulWidget {
  final ZoneRoom room;

  const ReservationDetailScreen({super.key, required this.room});

  @override
  State<ReservationDetailScreen> createState() =>
      _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final TextEditingController _purposeController = TextEditingController();

  List<ReservationSlot> _existingSlots = [];
  bool _isLoadingSlots = false;
  bool _isSubmitting = false;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _fetchDayReservations();
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) return;

      final res = await http.get(
        Uri.parse('$_baseUrl/api/v1/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        final name = body['data']?['name'] as String? ?? '';
        setState(() => _userName = name);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _fetchDayReservations() async {
    setState(() => _isLoadingSlots = true);

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) return;

      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      final res = await http.get(
        Uri.parse(
          '$_baseUrl/api/v1/zones/${widget.room.id}/reservations?date=$dateStr',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        final data = body['data'];
        final List<dynamic> list = data['reservationList'] ?? [];
        setState(() {
          _existingSlots = list
              .map((e) => ReservationSlot.fromJson(e as Map<String, dynamic>))
              .where((s) => s.status != 'CANCELLED')
              .toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF3182F6)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _existingSlots = [];
      });
      _fetchDayReservations();
    }
  }

  void _showTimePicker(bool isStart) {
    final now = DateTime.now();
    final initialDt = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      (now.minute ~/ 10) * 10,
    );

    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: Colors.white,
        child: Column(
          children: [
            Container(
              height: 50,
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                child: const Text('Done'),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                minuteInterval: 10,
                initialDateTime: initialDt,
                onDateTimeChanged: (DateTime d) {
                  setState(() {
                    if (isStart) {
                      _startTime = TimeOfDay.fromDateTime(d);
                    } else {
                      _endTime = TimeOfDay.fromDateTime(d);
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _toIso(DateTime date, TimeOfDay time) {
    final y = date.year;
    final mo = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final mi = time.minute.toString().padLeft(2, '0');
    return '$y-$mo-${d}T$h:$mi:00';
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return iso;
    }
  }

  Future<void> _submitReservation() async {
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('시작 시간과 종료 시간을 선택해 주세요.')));
      return;
    }

    final startDt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime!.hour,
      _startTime!.minute,
    );
    final endDt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _endTime!.hour,
      _endTime!.minute,
    );

    if (!endDt.isAfter(startDt)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('종료 시간은 시작 시간보다 늦어야 합니다.')));
      return;
    }

    final overlapping = _existingSlots.where((slot) {
      try {
        final existStart = DateTime.parse(slot.startTime);
        final existEnd = DateTime.parse(slot.endTime);
        return startDt.isBefore(existEnd) && endDt.isAfter(existStart);
      } catch (_) {
        return false;
      }
    }).toList();

    if (overlapping.isNotEmpty) {
      final times = overlapping
          .map((s) => '${_formatTime(s.startTime)}~${_formatTime(s.endTime)}')
          .join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('해당 시간대에 이미 예약이 있습니다. ($times)')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
        return;
      }

      final body = jsonEncode({
        'zoneId': widget.room.id,
        'startTime': _toIso(_selectedDate, _startTime!),
        'endTime': _toIso(_selectedDate, _endTime!),
        if (_purposeController.text.trim().isNotEmpty)
          'purpose': _purposeController.text.trim(),
      });

      final res = await http.post(
        Uri.parse('$_baseUrl/api/v1/reservations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('예약이 완료되었습니다.')));
        Navigator.pop(context);
      } else {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(decoded['message'] ?? '예약에 실패했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('서버에 연결할 수 없습니다.')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '${widget.room.name} 예약',
          style: const TextStyle(
            color: Color(0xFF191F28),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF191F28)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 날짜 선택
                    _buildLabel('예약 날짜'),
                    GestureDetector(
                      onTap: _selectDate,
                      child: _buildInput(
                        text:
                            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                        icon: Icons.calendar_today,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 시간 선택
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('시작 시간'),
                              GestureDetector(
                                onTap: () => _showTimePicker(true),
                                child: _buildInput(
                                  text: _startTime?.format(context) ?? '시간 선택',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('종료 시간'),
                              GestureDetector(
                                onTap: () => _showTimePicker(false),
                                child: _buildInput(
                                  text: _endTime?.format(context) ?? '시간 선택',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 예약자명
                    _buildLabel('예약자명'),
                    _buildInput(
                      text: _userName.isEmpty ? '불러오는 중...' : _userName,
                      icon: Icons.person_outline,
                      textColor: Colors.grey,
                    ),
                    const SizedBox(height: 20),

                    // 사용 목적
                    _buildLabel('사용 목적 (선택)'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _purposeController,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: '예) 팀 주간 회의',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Color(0xFF8B95A1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 당일 예약 현황
                    Row(
                      children: [
                        _buildLabel('당일 예약 현황'),
                        if (_isLoadingSlots)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF3182F6),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _existingSlots.isEmpty && !_isLoadingSlots
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                '해당 날짜에 예약이 없습니다.',
                                style: TextStyle(
                                  color: Color(0xFF8B95A1),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        : Column(
                            children: _existingSlots
                                .map((slot) => _buildSlotTile(slot))
                                .toList(),
                          ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelReservation(int reservationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('예약 취소', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('해당 예약을 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('아니요', style: TextStyle(color: Color(0xFF8B95A1))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('취소하기', style: TextStyle(color: Color(0xFFF04452))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) return;

      final res = await http.delete(
        Uri.parse('$_baseUrl/api/v1/reservations/$reservationId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('예약이 취소되었습니다.')),
        );
        _fetchDayReservations();
      } else {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(decoded['message'] ?? '취소에 실패했습니다.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('서버에 연결할 수 없습니다.')),
        );
      }
    }
  }

  Widget _buildSlotTile(ReservationSlot slot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEECEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 16, color: Color(0xFFF04452)),
          const SizedBox(width: 8),
          Text(
            '${_formatTime(slot.startTime)} ~ ${_formatTime(slot.endTime)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF04452),
            ),
          ),
          const Spacer(),
          Text(
            slot.status == 'CONFIRMED' ? '확정' : slot.status,
            style: const TextStyle(fontSize: 12, color: Color(0xFFF04452)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _cancelReservation(slot.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF04452),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '취소',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF8B95A1),
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _buildInput({required String text, IconData? icon, Color? textColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textColor ?? Colors.black,
            ),
          ),
          const Spacer(),
          if (icon != null)
            Icon(icon, size: 18, color: const Color(0xFF8B95A1)),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB900),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          onPressed: _isSubmitting ? null : _submitReservation,
          child: _isSubmitting
              ? const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                )
              : const Text(
                  '예약 완료하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
