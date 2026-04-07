import 'package:flutter/material.dart';

class ParkingScreen extends StatefulWidget {
  const ParkingScreen({super.key});

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  int _selectedFloor = 1; // 현재 선택된 층 (1F ~ 5F)

  // 🌟 실제 데이터 (나중에 서버/DB와 연동할 부분)
  // false: 주차 가능(초록), true: 주차 중(빨강)
  final Map<int, List<bool>> _parkingData = {
    1: [true, false, false, true, false, true, false, false], // 8칸 중 5칸 가능
    2: [false, false, true, false, true, false, false, false], // 8칸 중 6칸 가능
    3: [true, true, true, false, false, false, true, false], // 8칸 중 4칸 가능
    4: [false, true, false, false, false, true, false, true], // 8칸 중 5칸 가능
    5: [true, false, true, true, false, false, false, false], // 8칸 중 5칸 가능
  };

  // 🌟 특정 층의 '주차 가능(false)' 대수를 실시간으로 계산하는 함수
  int _getAvailableCount(int floor) {
    if (!_parkingData.containsKey(floor)) return 0;
    return _parkingData[floor]!.where((isOccupied) => !isOccupied).length;
  }

  // 🌟 전체 층의 '총 주차 가능' 대수를 실시간으로 계산하는 함수
  int _getTotalAvailableCount() {
    int total = 0;
    _parkingData.forEach((floor, data) {
      total += data.where((isOccupied) => !isOccupied).length;
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6), // 토스 배경색
      appBar: AppBar(
        title: const Text(
          '주차현황',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. 상단 주차 지도 카드
            Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 왼쪽: 층 선택 바
                  _buildFloorSelector(),
                  const SizedBox(width: 20),
                  // 오른쪽: 주차 격자 지도
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_selectedFloor층 주차장',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildParkingGrid(),
                        const SizedBox(height: 16),
                        _buildLegend(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. 하단 현재 주차 현황 요약 카드 (🌟 숫자가 자동으로 계산됩니다)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '현재 주차 현황',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // 🌟 각 층의 잔여 대수를 함수로 실시간 호출
                  _buildSummaryRow('5F', '${_getAvailableCount(5)}대 가능'),
                  _buildSummaryRow('4F', '${_getAvailableCount(4)}대 가능'),
                  _buildSummaryRow('3F', '${_getAvailableCount(3)}대 가능'),
                  _buildSummaryRow('2F', '${_getAvailableCount(2)}대 가능'),
                  _buildSummaryRow('1F', '${_getAvailableCount(1)}대 가능'),

                  const Divider(height: 32, color: Color(0xFFF2F4F6)),

                  // 🌟 전체 합계도 자동으로 계산
                  _buildSummaryRow(
                    '총 잔여 주차',
                    '${_getTotalAvailableCount()}대',
                    isTotal: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 층 선택 사이드 바
  Widget _buildFloorSelector() {
    return Column(
      children: [5, 4, 3, 2, 1].map((floor) {
        bool isSelected = _selectedFloor == floor;
        return GestureDetector(
          onTap: () => setState(() => _selectedFloor = floor),
          child: Container(
            width: 45,
            height: 45,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color.fromARGB(255, 248, 193, 43)
                  : const Color(0xFFF2F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${floor}F',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF8B95A1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // 주차 격자 지도 (선택된 층에 따라 실시간 변경)
  Widget _buildParkingGrid() {
    List<bool> currentFloorData = _parkingData[_selectedFloor]!;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.5,
      ),
      itemCount: currentFloorData.length,
      itemBuilder: (context, index) {
        bool isOccupied = currentFloorData[index];
        return Container(
          decoration: BoxDecoration(
            color: isOccupied
                ? const Color(0xFFFF4D4D)
                : const Color(0xFF2ECC71),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }

  // 범례 (색상 설명)
  Widget _buildLegend() {
    return Row(
      children: [
        _legendItem(const Color(0xFF2ECC71), '가능'),
        const SizedBox(width: 12),
        _legendItem(const Color(0xFFFF4D4D), '만차'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8B95A1)),
        ),
      ],
    );
  }

  // 요약 행 위젯 (🌟 MainAxisAlignment 오타 수정됨)
  Widget _buildSummaryRow(String floor, String count, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // 🌟 수정 완료
        children: [
          Text(
            floor,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal
                  ? const Color(0xFF191F28)
                  : const Color(0xFF4E5968),
            ),
          ),
          Text(
            count,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: isTotal
                  ? const Color.fromARGB(255, 248, 193, 43)
                  : const Color(0xFF191F28),
            ),
          ),
        ],
      ),
    );
  }
}
