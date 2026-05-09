import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// --- 1. 데이터 모델 및 매니저 ---
class Room {
  final String name;
  bool isAvailable;
  Room({required this.name, this.isAvailable = true});
}

class ReservationManager {
  static final ReservationManager _instance = ReservationManager._internal();
  factory ReservationManager() => _instance;
  ReservationManager._internal();

  List<Room> rooms = List.generate(
    8,
    (i) => Room(name: '회의실 ${i + 1}', isAvailable: true),
  );
}

// --- 2. 회의실 목록 화면 (Grid형) ---
class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});
  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  final manager = ReservationManager();

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
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: manager.rooms.length,
        itemBuilder: (context, index) => _buildRoomCard(manager.rooms[index]),
      ),
    );
  }

  Widget _buildRoomCard(Room room) {
    return GestureDetector(
      onTap: () {
        if (room.isAvailable) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReservationDetailScreen(room: room),
            ),
          ).then((_) => setState(() {})); // 돌아왔을 때 상태 업데이트
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
            Text(
              room.name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: room.isAvailable
                    ? const Color(0xFF333D4B)
                    : const Color(0xFFF04452),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: room.isAvailable
                    ? const Color(0xFFE8F3FF)
                    : const Color(0xFFFEECEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                room.isAvailable ? '예약하기' : '예약완료',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: room.isAvailable
                      ? const Color(0xFF3182F6)
                      : const Color(0xFFF04452),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 3. 예약 상세 화면 (고기능 통합형) ---
class ReservationDetailScreen extends StatefulWidget {
  final Room room;
  const ReservationDetailScreen({super.key, required this.room});
  @override
  State<ReservationDetailScreen> createState() =>
      _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final String _reserverName = "홍길동 (20212187)";

  final List<Map<String, String>> _employees = [
    {'id': '20210001', 'name': '김철수', 'dept': '개발팀'},
    {'id': '20210002', 'name': '이영희', 'dept': '디자인팀'},
    {'id': '20210003', 'name': '박지민', 'dept': '인사팀'},
    {'id': '20230555', 'name': '강동원', 'dept': '영업팀'},
  ];

  List<Map<String, String>> _selectedParticipants = [];
  List<Map<String, String>> _filteredResults = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final query = _searchController.text;
      if (query.isEmpty)
        setState(() => _filteredResults = []);
      else {
        setState(() {
          _filteredResults = _employees
              .where(
                (e) =>
                    (e['name']!.contains(query) || e['id']!.contains(query)) &&
                    !_selectedParticipants.contains(e),
              )
              .toList();
        });
      }
    });
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _showTimePicker(bool isStart) {
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
                onDateTimeChanged: (DateTime d) {
                  setState(() {
                    if (isStart)
                      _startTime = TimeOfDay.fromDateTime(d);
                    else
                      _endTime = TimeOfDay.fromDateTime(d);
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalCount = _selectedParticipants.length + 1;

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
                    _buildLabel("예약날짜"),
                    GestureDetector(
                      onTap: _selectDate,
                      child: _buildTossInput(
                        text:
                            "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}",
                        icon: Icons.calendar_today,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("예약시간"),
                              GestureDetector(
                                onTap: () => _showTimePicker(true),
                                child: _buildTossInput(
                                  text: _startTime?.format(context) ?? "시간 선택",
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
                              _buildLabel("종료시간"),
                              GestureDetector(
                                onTap: () => _showTimePicker(false),
                                child: _buildTossInput(
                                  text: _endTime?.format(context) ?? "시간 선택",
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildLabel("예약자명"),
                    _buildTossInput(
                      text: _reserverName,
                      color: const Color(0xFFF2F4F6),
                      textColor: Colors.grey,
                    ),
                    const SizedBox(height: 20),
                    _buildLabel("추가 참여자"),
                    _buildSearchField(),
                    if (_filteredResults.isNotEmpty) _buildSearchResults(),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: _selectedParticipants
                          .map(
                            (p) => Chip(
                              label: Text(
                                p['name']!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onDeleted: () => setState(
                                () => _selectedParticipants.remove(p),
                              ),
                              backgroundColor: const Color(0xFFF2F4F6),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    _buildLabel("참여 인원"),
                    _buildTossInput(
                      text: "$totalCount명",
                      color: const Color(0xFFF2F4F6),
                      textColor: Colors.grey,
                      icon: Icons.people,
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

  Widget _buildTossInput({
    required String text,
    IconData? icon,
    Color? color,
    Color? textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: textColor ?? Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (icon != null)
            Icon(icon, size: 18, color: const Color(0xFF8B95A1)),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: "사번 또는 이름 검색",
          border: InputBorder.none,
          icon: Icon(Icons.search, size: 20, color: Color(0xFF8B95A1)),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: const Color(0xFFF2F4F6)),
      ),
      child: Column(
        children: _filteredResults
            .map(
              (emp) => ListTile(
                title: Text(
                  emp['name']!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  "${emp['dept']} | ${emp['id']}",
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () {
                  setState(() {
                    _selectedParticipants.add(emp);
                    _searchController.clear();
                    _filteredResults = [];
                    FocusScope.of(context).unfocus();
                  });
                },
              ),
            )
            .toList(),
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
          onPressed: () {
            if (_startTime == null || _endTime == null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('시간을 선택해 주세요.')));
              return;
            }
            setState(() => widget.room.isAvailable = false);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('예약이 완료되었습니다.')));
            Navigator.pop(context);
          },
          child: const Text(
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
