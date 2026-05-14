import 'package:flutter/material.dart';

// 1. 데이터 모델 (밝기 대신 켜짐/꺼짐 상태로 변경)
class ZoneData {
  final String id;
  final String name;
  bool isLightOn;

  ZoneData({required this.id, required this.name, required this.isLightOn});
}

// 2. 싱글톤 매니저 (상태 유지)
class LightingSettings {
  static final LightingSettings _instance = LightingSettings._internal();
  factory LightingSettings() => _instance;
  LightingSettings._internal();

  final List<ZoneData> zones = [
    ZoneData(id: '1', name: 'A 구역', isLightOn: true),
    ZoneData(id: '2', name: 'B 구역', isLightOn: true),
    ZoneData(id: '3', name: 'C 구역', isLightOn: true),
    ZoneData(id: '4', name: 'D 구역', isLightOn: false),
    ZoneData(id: '5', name: 'E 구역', isLightOn: false),
    ZoneData(id: '6', name: 'F 구역', isLightOn: false),
  ];

  int selectedIndex = 0;
}

class LightingControlScreen extends StatefulWidget {
  const LightingControlScreen({super.key});

  @override
  State<LightingControlScreen> createState() => _LightingControlScreenState();
}

class _LightingControlScreenState extends State<LightingControlScreen> {
  final LightingSettings _settings = LightingSettings();

  @override
  Widget build(BuildContext context) {
    final selectedZone = _settings.zones[_settings.selectedIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: AppBar(
        title: const Text(
          '조명 ON/OFF',
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
            // 1. 상단 구역 현황 그리드
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.lightbulb,
                          color: Color(0xFFFFB800),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '전체 구역 조명 현황',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF191F28),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 2.0, // 타일의 가로세로 비율 조절
                          ),
                      itemCount: _settings.zones.length,
                      itemBuilder: (context, index) {
                        final zone = _settings.zones[index];
                        final isSelected = index == _settings.selectedIndex;

                        return GestureDetector(
                          onTap: () =>
                              setState(() => _settings.selectedIndex = index),
                          child: Container(
                            // 상하 패딩을 줄여서 오버플로우 에러 방지
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFE8F3FF)
                                  : const Color(0xFFF2F4F6),
                              borderRadius: BorderRadius.circular(20),
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(0xFF3182F6),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      zone.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? const Color(0xFF3182F6)
                                            : const Color(0xFF4E5968),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      zone.isLightOn ? '켜짐' : '꺼짐',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? const Color(0xFF3182F6)
                                            : const Color(0xFF191F28),
                                      ),
                                    ),
                                  ],
                                ),
                                if (zone.isLightOn)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFB800),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 2. 메인 조절 카드 (ON/OFF 토글)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE5E8EB)),
                ),
                child: Column(
                  children: [
                    // 아이콘 섹션 (상태에 따라 색상 변화)
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: selectedZone.isLightOn
                            ? const Color(0xFFFFF8E1)
                            : const Color(0xFFF2F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lightbulb,
                        color: selectedZone.isLightOn
                            ? const Color(0xFFFFB800)
                            : const Color(0xFF8B95A1),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '${selectedZone.name} 기기 설정',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8B95A1),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '현재 조명 ${selectedZone.isLightOn ? "작동 중" : "중지됨"}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF191F28),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 메인 컨트롤 토글 스위치 (ON/OFF 정중앙 배치)
                    GestureDetector(
                      onTap: () => setState(
                        () => selectedZone.isLightOn = !selectedZone.isLightOn,
                      ),
                      child: Container(
                        width: double.infinity,
                        height: 72,
                        decoration: BoxDecoration(
                          color: selectedZone.isLightOn
                              ? const Color.fromARGB(255, 248, 193, 43)
                              : const Color(0xFFE5E8EB),
                          borderRadius: BorderRadius.circular(36),
                        ),
                        child: Stack(
                          alignment: Alignment.center, // 전체 자식 기본 정렬을 중앙으로 설정
                          children: [
                            // ON / OFF 텍스트 (위치 고정 및 정중앙 정렬)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'ON',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(
                                        selectedZone.isLightOn ? 1.0 : 0.3,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  Text(
                                    'OFF',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(
                                        !selectedZone.isLightOn ? 1.0 : 0.3,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 움직이는 핸들 버튼
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              left: selectedZone.isLightOn ? null : 4,
                              right: selectedZone.isLightOn ? 4 : null,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.power_settings_new,
                                  color: selectedZone.isLightOn
                                      ? const Color.fromARGB(255, 248, 193, 43)
                                      : const Color(0xFF8B95A1),
                                  size: 30,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. 하단 안내 문구
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF3182F6),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
