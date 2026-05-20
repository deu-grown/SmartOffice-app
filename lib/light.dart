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
  static const String _baseUrl = 'http://10.0.2.2:8080';

  List<LightZoneData> _zones = [];
  int _selectedIndex = 0;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchZonesAndDevices();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _fetchZonesAndDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = '로그인이 필요합니다.';
            _isLoading = false;
          });
        }
        return;
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // 1. 전체 장치 목록 조회 (zoneId, zoneName 포함)
      final devRes = await http.get(
        Uri.parse('$_baseUrl/api/v1/devices'),
        headers: headers,
      );

      if (!mounted) return;

      if (devRes.statusCode != 200) {
        setState(() {
          _errorMessage = '장치 정보를 불러올 수 없습니다. (${devRes.statusCode})';
          _isLoading = false;
        });
        return;
      }

      final devBody = jsonDecode(utf8.decode(devRes.bodyBytes));
      if (devBody['code'] != 'success') {
        setState(() {
          _errorMessage = '장치 데이터 오류';
          _isLoading = false;
        });
        return;
      }

      final List<dynamic> allDevices = devBody['data'] ?? [];

      // 2. ACTIVE 장치를 zoneId 기준으로 그룹화 (첫 번째 장치만 사용)
      final Map<int, Map<String, dynamic>> zoneDeviceMap = {};
      for (final dev in allDevices) {
        if ((dev['status'] as String?) != 'ACTIVE') continue;
        final zoneId = dev['zoneId'] as int?;
        if (zoneId == null) continue;
        zoneDeviceMap.putIfAbsent(zoneId, () => dev);
      }

      if (zoneDeviceMap.isEmpty) {
        setState(() {
          _errorMessage = '제어 가능한 장치가 없습니다.';
          _isLoading = false;
        });
        return;
      }

      // 3. 구역별 LightZoneData 생성
      final List<LightZoneData> result = [];
      final seenZones = <int>{};

      for (final dev in allDevices) {
        if ((dev['status'] as String?) != 'ACTIVE') continue;
        final zoneId = dev['zoneId'] as int?;
        if (zoneId == null || seenZones.contains(zoneId)) continue;
        seenZones.add(zoneId);

        final zoneName = dev['zoneName'] as String? ?? '구역 $zoneId';
        final deviceId = dev['id'] as int?;

        result.add(
          LightZoneData(
            zoneId: zoneId,
            zoneName: zoneName,
            deviceId: deviceId,
            isLightOn: false,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _zones = result;
          _selectedIndex = 0;
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

  Future<void> _toggleLight(int index) async {
    final zone = _zones[index];

    if (zone.deviceId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이 구역에 제어 가능한 장치가 없습니다.')));
      return;
    }

    final newState = !zone.isLightOn;

    // 낙관적 UI 업데이트
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
        // 실패 시 롤백
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
            onPressed: _fetchZonesAndDevices,
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
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _fetchZonesAndDevices,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_zones.isEmpty) return const SizedBox.shrink();
    final selectedZone = _zones[_selectedIndex];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 구역 현황 그리드
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
                                          zone.deviceId == null
                                              ? '장치 없음'
                                              : zone.isLightOn
                                              ? '켜짐'
                                              : '꺼짐',
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

          // 메인 조절 카드
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
                    selectedZone.deviceId == null
                        ? '제어 가능한 장치 없음'
                        : '현재 조명 ${selectedZone.isLightOn ? "작동 중" : "중지됨"}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF191F28),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ON/OFF 토글
                  GestureDetector(
                    onTap:
                        selectedZone.isSending || selectedZone.deviceId == null
                        ? null
                        : () => _toggleLight(_selectedIndex),
                    child: Container(
                      width: double.infinity,
                      height: 72,
                      decoration: BoxDecoration(
                        color: selectedZone.deviceId == null
                            ? const Color(0xFFE5E8EB)
                            : selectedZone.isLightOn
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

          // 하단 안내 문구
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
                  Expanded(
                    child: Text(
                      '조명 상태 변경 시 MQTT를 통해 실제 장치에 명령이 전달됩니다.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF8B95A1)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
