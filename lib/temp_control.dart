import 'package:flutter/material.dart';

// 1. 데이터를 관리하는 매니저 클래스 (앱이 켜져 있는 동안 데이터 유지)
class RoomSettings {
  static final RoomSettings _instance = RoomSettings._internal();
  factory RoomSettings() => _instance;
  RoomSettings._internal();

  // 처음 앱 실행 시 초기 데이터
  final List<RoomData> rooms = [
    RoomData(name: '회의실 A', temp: 22.0, humidity: 45),
    RoomData(name: '회의실 B', temp: 24.5, humidity: 50),
    RoomData(name: '대회의실', temp: 21.0, humidity: 40),
    RoomData(name: '라운지', temp: 23.0, humidity: 48),
    RoomData(name: '포커스룸', temp: 25.0, humidity: 35),
  ];

  int lastSelectedIndex = 0; // 마지막으로 선택했던 방 기억
}

// 방 데이터 모델
class RoomData {
  final String name;
  double temp;
  int humidity;

  RoomData({required this.name, required this.temp, required this.humidity});
}

class TempControlScreen extends StatefulWidget {
  const TempControlScreen({super.key});

  @override
  State<TempControlScreen> createState() => _TempControlScreenState();
}

class _TempControlScreenState extends State<TempControlScreen> {
  // 2. 싱글톤 인스턴스를 가져옵니다.
  final RoomSettings _settings = RoomSettings();

  @override
  Widget build(BuildContext context) {
    // 현재 선택된 방 데이터 참조
    final selectedRoom = _settings.rooms[_settings.lastSelectedIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: AppBar(
        title: const Text(
          '실내 온·습도 조절',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Text(
                '공간 선택',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4E5968),
                ),
              ),
            ),

            // 회의실 선택 가로 스크롤바
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(_settings.rooms.length, (index) {
                  return _buildRoomChip(index);
                }),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // 상단 현재 상태 카드
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
                          '${selectedRoom.temp.toStringAsFixed(1)}°C',
                          Icons.thermostat,
                          Colors.orange,
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFF2F4F6)),
                        const SizedBox(height: 16),
                        _buildStatusRow(
                          '현재 습도',
                          '${selectedRoom.humidity}%',
                          Icons.water_drop,
                          Colors.blue,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 온도 조절 카드
                  _buildControlCard(
                    title: '${selectedRoom.name} 온도 설정',
                    value: '${selectedRoom.temp.toStringAsFixed(1)}°C',
                    icon: Icons.thermostat,
                    iconColor: Colors.orange,
                    onIncrease: () => setState(() => selectedRoom.temp += 0.5),
                    onDecrease: () => setState(() => selectedRoom.temp -= 0.5),
                  ),
                  const SizedBox(height: 16),

                  // 습도 조절 카드
                  _buildControlCard(
                    title: '${selectedRoom.name} 습도 설정',
                    value: '${selectedRoom.humidity}%',
                    icon: Icons.water_drop,
                    iconColor: Colors.blue,
                    onIncrease: () =>
                        setState(() => selectedRoom.humidity += 1),
                    onDecrease: () =>
                        setState(() => selectedRoom.humidity -= 1),
                  ),

                  const SizedBox(height: 40),
                  Text(
                    '설정된 온·습도는 ${selectedRoom.name}에 즉시 적용됩니다.',
                    style: const TextStyle(
                      color: Color(0xFF8B95A1),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 공간 선택 칩 위젯
  Widget _buildRoomChip(int index) {
    bool isSelected = _settings.lastSelectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _settings.lastSelectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color.fromARGB(255, 248, 193, 43)
              : Colors.white,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color.fromARGB(255, 248, 193, 43).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Text(
          _settings.rooms[index].name,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF4E5968),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // 이하 공통 UI 위젯들은 동일...
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
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFF2F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(width: 20),
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
