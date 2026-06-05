import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LightZoneData {
  final int zoneId;
  final String zoneName;
  final int? deviceId;
  bool isLightOn;
  bool isSending;

  LightZoneData({
    required this.zoneId,
    required this.zoneName,
    this.deviceId,
    required this.isLightOn,
    this.isSending = false,
  });
}

class LightingControlScreen extends StatefulWidget {
  const LightingControlScreen({super.key});

  @override
  State<LightingControlScreen> createState() => _LightingControlScreenState();
}

class _LightingControlScreenState extends State<LightingControlScreen> {
  static const String _baseUrl = 'https://api.sjparkx1129.com';

  // V15 시드 기반 — 구역별 첫 번째 LIGHT 장치
  static const _zoneDeviceMap = [
    {'zoneId': 2, 'zoneName': '회의실 A', 'deviceId': 21},
    {'zoneId': 4, 'zoneName': '회의실 B', 'deviceId': 24},
    {'zoneId': 5, 'zoneName': '개발팀 좌석', 'deviceId': 29},
    {'zoneId': 7, 'zoneName': '서버실', 'deviceId': 34},
    {'zoneId': 10, 'zoneName': '회의실 C', 'deviceId': 37},
    {'zoneId': 11, 'zoneName': '회의실 D', 'deviceId': 40},
    {'zoneId': 12, 'zoneName': '회의실 E', 'deviceId': 44},
    {'zoneId': 13, 'zoneName': '휴게실', 'deviceId': 48},
    {'zoneId': 14, 'zoneName': '카페 라운지', 'deviceId': 51},
  ];

  List<LightZoneData> _zones = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _zones = _zoneDeviceMap
        .map(
          (z) => LightZoneData(
            zoneId: z['zoneId'] as int,
            zoneName: z['zoneName'] as String,
            deviceId: z['deviceId'] as int,
            isLightOn: false,
          ),
        )
        .toList();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _toggleLight(int index) async {
    final zone = _zones[index];

    if (zone.deviceId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이 구역에 제어 가능한 장치가 없습니다.')));
      return;
    }

    final newState = !zone.isLightOn;

    setState(() {
      _zones[index].isLightOn = newState;
      _zones[index].isSending = true;
    });

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() {
            _zones[index].isLightOn = !newState;
            _zones[index].isSending = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
        }
        return;
      }

      final body = jsonEncode({
        'zoneId': zone.zoneId,
        'deviceId': zone.deviceId,
        'command': 'LIGHT',
        'value': newState ? 'ON' : 'OFF',
      });

      final res = await http.post(
        Uri.parse('$_baseUrl/api/v1/controls'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        setState(() => _zones[index].isSending = false);
      } else {
        setState(() {
          _zones[index].isLightOn = !newState;
          _zones[index].isSending = false;
        });
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(decoded['message'] ?? '제어 명령 발송에 실패했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _zones[index].isLightOn = !newState;
          _zones[index].isSending = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('서버에 연결할 수 없습니다.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4E5968)),
            onPressed: () {
              setState(() {
                for (final z in _zones) {
                  z.isLightOn = false;
                  z.isSending = false;
                }
                _selectedIndex = 0;
              });
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_zones.isEmpty) return const SizedBox.shrink();
    final selectedZone = _zones[_selectedIndex];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      Icon(Icons.lightbulb, color: Color(0xFFFFB800), size: 20),
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
                          childAspectRatio: 2.0,
                        ),
                    itemCount: _zones.length,
                    itemBuilder: (context, index) {
                      final zone = _zones[index];
                      final isSelected = index == _selectedIndex;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedIndex = index),
                        child: Container(
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
                                    zone.zoneName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? const Color(0xFF3182F6)
                                          : const Color(0xFF4E5968),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  zone.isSending
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF3182F6),
                                          ),
                                        )
                                      : Text(
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
                              if (zone.isLightOn && !zone.isSending)
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
                    '${selectedZone.zoneName} 기기 설정',
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

                  GestureDetector(
                    onTap: selectedZone.isSending
                        ? null
                        : () => _toggleLight(_selectedIndex),
                    child: Container(
                      width: double.infinity,
                      height: 72,
                      decoration: BoxDecoration(
                        color: selectedZone.isLightOn
                            ? const Color.fromARGB(255, 248, 193, 43)
                            : const Color(0xFFE5E8EB),
                        borderRadius: BorderRadius.circular(36),
                      ),
                      child: selectedZone.isSending
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
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
                                          ? const Color.fromARGB(
                                              255,
                                              248,
                                              193,
                                              43,
                                            )
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

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF3182F6), size: 24),
                  SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
