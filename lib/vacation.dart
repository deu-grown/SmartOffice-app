import 'package:flutter/material.dart';

class VacationScreen extends StatefulWidget {
  const VacationScreen({super.key});

  @override
  State<VacationScreen> createState() => _VacationScreenState();
}

class _VacationScreenState extends State<VacationScreen> {
  // Static variables for persistence across screen navigations
  static double staticAvailableDays = 14.0;
  static List<DateTime> staticAppliedVacations = [];

  late DateTime focusedDate;
  DateTime? startDate;
  DateTime? endDate;
  String selectedUnit = '종일';
  String selectedHalfDayType = '오전';
  int? startHour;
  int? endHour;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    focusedDate = DateTime(now.year, now.month);
  }

  void _onDateClick(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Prevent selecting past dates
    if (date.isBefore(today)) {
      _showSnackBar('오늘 이전 날짜는 선택할 수 없습니다.');
      return;
    }

    setState(() {
      // Single day mode for Half-day or Hourly
      if (selectedUnit != '종일') {
        if (startDate != null && date.isAtSameMomentAs(startDate!)) {
          startDate = null;
        } else {
          startDate = date;
        }
        endDate = null;
        return;
      }

      // Range mode for Full-day
      if (startDate != null && date.isAtSameMomentAs(startDate!)) {
        // Toggle off start date
        startDate = endDate;
        endDate = null;
      } else if (endDate != null && date.isAtSameMomentAs(endDate!)) {
        // Toggle off end date
        endDate = null;
      } else if (startDate == null || (startDate != null && endDate != null)) {
        startDate = date;
        endDate = null;
      } else {
        if (date.isBefore(startDate!)) {
          endDate = startDate;
          startDate = date;
        } else {
          endDate = date;
        }
      }
    });
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  void _applyVacation() {
    if (startDate == null) {
      _showSnackBar('날짜를 선택해주세요.');
      return;
    }

    if (selectedUnit == '시간' && (startHour == null || endHour == null)) {
      _showSnackBar('시작 및 종료 시간을 설정해주세요.');
      return;
    }

    double daysToDeduct = 0;
    if (selectedUnit == '종일') {
      daysToDeduct = endDate == null
          ? 1.0
          : endDate!.difference(startDate!).inDays + 1.0;
    } else if (selectedUnit == '반차') {
      daysToDeduct = 0.5;
    } else {
      if (startHour != null && endHour != null) {
        final diffHours = endHour! - startHour!;
        if (diffHours <= 0) {
          _showSnackBar('종료 시간은 시작 시간보다 늦어야 합니다.');
          return;
        }
        daysToDeduct = diffHours / 8.0;
      }
    }

    if (staticAvailableDays < daysToDeduct) {
      _showSnackBar('잔여 휴가가 부족합니다.');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '휴가 신청',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(_getDialogContent()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Color(0xFF8B95A1))),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                staticAvailableDays -= daysToDeduct;
                if (endDate != null) {
                  int days = endDate!.difference(startDate!).inDays;
                  for (int i = 0; i <= days; i++) {
                    staticAppliedVacations.add(
                      startDate!.add(Duration(days: i)),
                    );
                  }
                } else {
                  staticAppliedVacations.add(startDate!);
                }
                startDate = null;
                endDate = null;
                startHour = null;
                endHour = null;
              });
              Navigator.pop(context);
              _showSnackBar('신청이 완료되었습니다.', isSuccess: true);
            },
            child: const Text(
              '신청',
              style: TextStyle(
                color: Color(0xFF3182F6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12:00 a.m.';
    if (hour < 12) return '$hour:00 a.m.';
    if (hour == 12) return '12:00 p.m.';
    return '${hour - 12}:00 p.m.';
  }

  String _getDialogContent() {
    String dateStr = '${startDate!.month}월 ${startDate!.day}일';
    if (endDate != null) dateStr += ' ~ ${endDate!.month}월 ${endDate!.day}일';

    String detailStr = selectedUnit;
    if (selectedUnit == '반차') detailStr = '$selectedHalfDayType 반차';
    if (selectedUnit == '시간') {
      detailStr = '시간 (${_formatHour(startHour!)}~${_formatHour(endHour!)})';
    }

    return '$dateStr ($detailStr) 휴가를 신청할까요?';
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? const Color(0xFF3182F6) : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF191F28)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '휴가 조회/신청',
          style: TextStyle(
            color: Color(0xFF191F28),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVacationHeader(),
              const SizedBox(height: 24),
              _buildCalendarCard(),
              const SizedBox(height: 24),
              _buildUnitSelector(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVacationHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '연차 휴가',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF333D4B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${DateTime.now().year} ▼',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '신청 가능',
                        style: TextStyle(
                          color: Color(0xFF4E5968),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${staticAvailableDays.toString().replaceAll(RegExp(r'\.0$'), '')}일',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.info_outline, color: Colors.grey[300]),
                ],
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '사용 가능 기간',
                    style: TextStyle(color: Color(0xFF8B95A1), fontSize: 12),
                  ),
                  Text(
                    '${DateTime.now().year}.01.01 ~ 12.31',
                    style: const TextStyle(
                      color: Color(0xFF4E5968),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${staticAvailableDays.toString().replaceAll(RegExp(r'\.0$'), '')}일 >',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Color(0xFF8B95A1)),
                onPressed: () => setState(
                  () => focusedDate = DateTime(
                    focusedDate.year,
                    focusedDate.month - 1,
                  ),
                ),
              ),
              Text(
                '${focusedDate.year}.${focusedDate.month.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Color(0xFF8B95A1)),
                onPressed: () => setState(
                  () => focusedDate = DateTime(
                    focusedDate.year,
                    focusedDate.month + 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCalendar(),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildDateDisplay('시작일', startDate)),
              Expanded(child: _buildDateDisplay('종료일', endDate ?? startDate)),
            ],
          ),
        ],
      ),
    );
  }

  bool _isRange(DateTime date) {
    if (startDate == null || endDate == null) return false;
    return date.isAfter(startDate!) && date.isBefore(endDate!);
  }

  bool _isSelected(DateTime date) {
    return (startDate != null && date.isAtSameMomentAs(startDate!)) ||
        (endDate != null && date.isAtSameMomentAs(endDate!));
  }

  Widget _buildCalendar() {
    final daysInMonth = DateTime(
      focusedDate.year,
      focusedDate.month + 1,
      0,
    ).day;
    final firstDay =
        DateTime(focusedDate.year, focusedDate.month, 1).weekday % 7;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['일', '월', '화', '수', '목', '금', '토']
              .map(
                (d) => Text(
                  d,
                  style: const TextStyle(
                    color: Color(0xFF8B95A1),
                    fontSize: 12,
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: daysInMonth + firstDay,
          itemBuilder: (context, index) {
            if (index < firstDay) return const SizedBox();
            final day = index - firstDay + 1;
            final date = DateTime(focusedDate.year, focusedDate.month, day);
            final isAppplied = staticAppliedVacations.any(
              (d) =>
                  d.day == date.day &&
                  d.month == date.month &&
                  d.year == date.year,
            );
            final selected = _isSelected(date);
            final inRange = _isRange(date);
            final isToday = _isToday(date);

            // Check if date is in the past
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final isPast = date.isBefore(today);

            return GestureDetector(
              onTap: () => _onDateClick(date),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (inRange)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      color: Colors.blue.withOpacity(0.1),
                    ),
                  if (startDate != null &&
                      endDate != null &&
                      date.isAtSameMomentAs(startDate!))
                    Positioned(
                      right: 0,
                      child: Container(
                        width: 20,
                        height: 32,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                    ),
                  if (startDate != null &&
                      endDate != null &&
                      date.isAtSameMomentAs(endDate!))
                    Positioned(
                      left: 0,
                      child: Container(
                        width: 20,
                        height: 32,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                    ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF3182F6)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isToday
                          ? Border.all(color: Colors.orange, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : (isAppplied
                                    ? Colors.blue
                                    : (isToday
                                          ? Colors.orange
                                          : (isPast
                                                ? const Color(0xFFC0C0C0)
                                                : const Color(0xFF333D4B)))),
                          fontWeight: FontWeight.bold,
                          decoration: isAppplied
                              ? TextDecoration.underline
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDateDisplay(String label, DateTime? date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8B95A1), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          date == null
              ? '-'
              : '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildUnitSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '단위',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (selectedUnit == '반차')
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: ['오전', '오후'].map((type) {
                    final isTypeSelected = selectedHalfDayType == type;
                    return GestureDetector(
                      onTap: () => setState(() => selectedHalfDayType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isTypeSelected
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isTypeSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isTypeSelected
                                ? const Color(0xFF191F28)
                                : const Color(0xFF8B95A1),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (selectedUnit == '시간') _buildTimeRangeSelector(),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: ['종일', '반차', '시간'].map((unit) {
              final isSelected = unit == selectedUnit;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    selectedUnit = unit;
                    // When switching to non-Full-day units, clear the end date
                    if (selectedUnit != '종일') {
                      endDate = null;
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        unit,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? const Color(0xFF191F28)
                              : const Color(0xFF8B95A1),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRangeSelector() {
    return Row(
      children: [
        _buildTimePlaceholder(
          '나가는 시간',
          startHour,
          (h) => setState(() => startHour = h),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '~',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
        _buildTimePlaceholder(
          '돌아오는 시간',
          endHour,
          (h) => setState(() => endHour = h),
        ),
      ],
    );
  }

  Widget _buildTimePlaceholder(
    String label,
    int? selectedHour,
    Function(int) onSelected,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E8EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: selectedHour,
            hint: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
            onChanged: (int? newValue) {
              if (newValue != null) onSelected(newValue);
            },
            items: List.generate(24, (index) => index)
                .map<DropdownMenuItem<int>>((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(
                      _formatHour(value),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                })
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _applyVacation,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3182F6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
          '신청하기',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
