import 'dart:convert';
import 'package:flutter/material.dart';
import 'auth_http.dart';

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
  List<LightZoneData> _zones = [];
  int _selectedIndex = 0;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchLights();
  }

  // 서버에서 ACTIVE 조명 장치 목록을 받아 구역별 첫 장치로 구성한다.
  Future<void> _fetchLights() async {
    try {
      final res = await AuthHttp.instance.get('/api/v1/devices/lights');
      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        if (body['code'] == 'success') {
          final List<dynamic> list = body['data'] as List<dynamic>;
          // 서버가 zoneId·deviceId 순으로 정렬해 내려주므로 구역별 첫 장치만 취한다.
          final Map<int, LightZoneData> byZone = {};
          for (final item in list) {
            final zoneId = item['zoneId'] as int;
            if (byZone.containsKey(zoneId)) continue;
            byZone[zoneId] = LightZoneData(
              zoneId: zoneId,
              zoneName: item['zoneName'] as String,
              deviceId: item['deviceId'] as int,
              isLightOn: false,
            );
          }
          setState(() {
            _zones = byZone.values.toList();
            if (_selectedIndex >= _zones.length) _selectedIndex = 0;
            _isLoading = false;
            _errorMessage = '';
          });
          return;
        }
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '조명 목록을 불러오지 못했습니다.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '서버에 연결할 수 없습니다.';
      });
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

    // 응답 처리는 캡처한 zone 객체를 직접 갱신한다. 전송 중 refresh 재조회로
    // _zones 가 교체·축소돼도 인덱스를 다시 타지 않아 RangeError 가 발생하지 않는다.
    // (재조회로 버려진 옛 zone 객체를 갱신하더라도 새 리스트에는 영향이 없다.)
    setState(() {
      zone.isLightOn = newState;
      zone.isSending = true;
    });

    try {
      final res = await AuthHttp.instance.post(
        '/api/v1/controls',
        body: {
          'zoneId': zone.zoneId,
          'deviceId': zone.deviceId,
          'command': 'LIGHT',
          'value': newState ? 'ON' : 'OFF',
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        setState(() => zone.isSending = false);
      } else {
        setState(() {
          zone.isLightOn = !newState;
          zone.isSending = false;
        });
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(decoded['message'] ?? '제어 명령 발송에 실패했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          zone.isLightOn = !newState;
          zone.isSending = false;
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
              setState(() => _isLoading = true);
              _fetchLights();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4E5968)),
      );
    }
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFD1D6DB)),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(color: Color(0xFF8B95A1), fontSize: 15),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchLights();
              },
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    if (_zones.isEmpty) {
      return const Center(
        child: Text(
          '제어 가능한 조명이 없습니다.',
          style: TextStyle(color: Color(0xFF8B95A1), fontSize: 15),
        ),
      );
    }
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
