import 'package:flutter/material.dart';

class TempControlScreen extends StatefulWidget {
  const TempControlScreen({super.key});

  @override
  State<TempControlScreen> createState() => _TempControlScreenState();
}

class _TempControlScreenState extends State<TempControlScreen> {
  double _currentTemp = 15.0; // 현재 온도
  int _currentHumidity = 40; // 현재 습도

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6), // 토스 배경색
      appBar: AppBar(
        title: const Text(
          '온·습도 조절',
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // 1. 상단 현재 상태 요약 카드
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  _buildStatusRow(
                    '현재 온도',
                    '${_currentTemp.toStringAsFixed(1)}°C',
                    Icons.thermostat,
                    Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF2F4F6)),
                  const SizedBox(height: 16),
                  _buildStatusRow(
                    '현재 습도',
                    '$_currentHumidity%',
                    Icons.water_drop,
                    Colors.blue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. 온도 조절 카드
            _buildControlCard(
              title: '온도 설정',
              value: '${_currentTemp.toStringAsFixed(1)}°C',
              icon: Icons.thermostat,
              iconColor: Colors.orange,
              onIncrease: () => setState(() => _currentTemp += 0.5),
              onDecrease: () => setState(() => _currentTemp -= 0.5),
            ),
            const SizedBox(height: 16),

            // 3. 습도 조절 카드
            _buildControlCard(
              title: '습도 설정',
              value: '$_currentHumidity%',
              icon: Icons.water_drop,
              iconColor: Colors.blue,
              onIncrease: () => setState(() => _currentHumidity += 1),
              onDecrease: () => setState(() => _currentHumidity -= 1),
            ),

            const SizedBox(height: 40),
            // 하단 안내 문구
            const Text(
              '설정된 온·습도는 사무실 전체에 적용됩니다.',
              style: TextStyle(color: Color(0xFF8B95A1), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // 현재 상태 표시 행 위젯
  Widget _buildStatusRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF4E5968),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF191F28),
          ),
        ),
      ],
    );
  }

  // 조절 카드 위젯 (온도/습도 공용)
  Widget _buildControlCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onIncrease,
    required VoidCallback onDecrease,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // 왼쪽 아이콘
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(width: 20),
          // 중간 텍스트 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8B95A1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF191F28),
                  ),
                ),
              ],
            ),
          ),
          // 오른쪽 조절 버튼 (위/아래 화살표)
          Column(
            children: [
              _buildRoundButton(Icons.keyboard_arrow_up, onIncrease),
              const SizedBox(height: 12),
              _buildRoundButton(Icons.keyboard_arrow_down, onDecrease),
            ],
          ),
        ],
      ),
    );
  }

  // 동그란 조절 버튼
  Widget _buildRoundButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF4E5968), size: 24),
      ),
    );
  }
}
