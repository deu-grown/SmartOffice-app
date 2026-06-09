import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'auth_http.dart';

class ParkingScreen extends StatefulWidget {
  const ParkingScreen({super.key});

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  // ─────────────────────────────────────────────
  // 주차장 구역 매핑 — 백엔드 zones 시드와 일치
  //   key   : 백엔드 zone_id
  //   value : 화면에 표시할 층 이름
  // 백엔드 시드: zone 8 = 지하1층, zone 9 = 지하2층
  // ─────────────────────────────────────────────
  static const Map<int, String> parkingZones = {
    8: '지하1층',
    9: '지하2층',
  };

  // 좌측 셀렉터에 표시할 짧은 라벨 (지하1층 → B1)
  static String _zoneShortLabel(int zoneId) {
    switch (zoneId) {
      case 8:
        return 'B1';
      case 9:
        return 'B2';
      default:
        return '${zoneId}F';
    }
  }

  // 초기 선택은 parkingZones 의 첫 번째 키 (현재: 지하1층=8)
  int _selectedZoneId = parkingZones.keys.first;
  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _refreshTimer;

  // API 응답 데이터
  String _zoneName = '';
  int _totalSpots = 0;
  int _occupiedSpots = 0;
  int _availableSpots = 0;
  List<Map<String, dynamic>> _spots = [];

  // 각 구역별 요약 (하단 현황용)
  Map<int, Map<String, dynamic>> _zoneSummary = {};

  @override
  void initState() {
    super.initState();
    _fetchParkingData();
    _fetchAllZoneSummary();

    // 5초마다 자동 새로고침
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchParkingData();
      _fetchAllZoneSummary();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // 선택된 구역 주차 현황 조회
  // ─────────────────────────────────────────────

  Future<void> _fetchParkingData() async {
    try {
      final response = await AuthHttp.instance.get(
        '/api/v1/parking/zones/$_selectedZoneId/spots',
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final json = jsonDecode(decodedBody);

        if (json['code'] == 'success') {
          final data = json['data'];
          setState(() {
            _zoneName = data['zoneName'] ?? '';
            _totalSpots = data['totalSpots'] ?? 0;
            _occupiedSpots = data['occupiedSpots'] ?? 0;
            _availableSpots = data['availableSpots'] ?? 0;
            _spots = List<Map<String, dynamic>>.from(data['spots'] ?? []);
            _isLoading = false;
            _errorMessage = '';
          });
        }
      } else {
        setState(() {
          _errorMessage = '데이터를 불러올 수 없습니다.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '서버에 연결할 수 없습니다.';
        _isLoading = false;
      });
    }
  }

  // ─────────────────────────────────────────────
  // 전체 구역 요약 조회 (하단 현황 카드용)
  // ─────────────────────────────────────────────

  Future<void> _fetchAllZoneSummary() async {
    try {
      for (final zoneId in parkingZones.keys) {
        final response = await AuthHttp.instance.get(
          '/api/v1/parking/zones/$zoneId/spots',
        );

        if (response.statusCode == 200) {
          final decodedBody = utf8.decode(response.bodyBytes);
          final json = jsonDecode(decodedBody);
          if (json['code'] == 'success') {
            final data = json['data'];
            if (mounted) {
              setState(() {
                _zoneSummary[zoneId] = {
                  'zoneName': data['zoneName'] ?? parkingZones[zoneId],
                  'availableSpots': data['availableSpots'] ?? 0,
                  'totalSpots': data['totalSpots'] ?? 0,
                };
              });
            }
          }
        }
      }
    } catch (_) {}
  }

  // 층 변경 시 호출
  void _onZoneChanged(int zoneId) {
    setState(() {
      _selectedZoneId = zoneId;
      _isLoading = true;
      _spots = [];
    });
    _fetchParkingData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4E5968)),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchParkingData();
              _fetchAllZoneSummary();
            },
          ),
        ],
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
                  _buildZoneSelector(),
                  const SizedBox(width: 20),
                  // 오른쪽: 주차 격자
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _zoneName.isEmpty
                                  ? parkingZones[_selectedZoneId]!
                                  : _zoneName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // 실시간 표시
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2ECC71),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF2ECC71),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (!_isLoading && _errorMessage.isEmpty)
                          Text(
                            '총 $_totalSpots면 · 가능 $_availableSpots면 · 점유 $_occupiedSpots면',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8B95A1),
                            ),
                          ),
                        const SizedBox(height: 16),
                        _isLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF4E5968),
                                  ),
                                ),
                              )
                            : _errorMessage.isNotEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    _errorMessage,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                            : _buildParkingGrid(),
                        const SizedBox(height: 16),
                        _buildLegend(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. 하단 전체 현황 요약 카드
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
                  ...parkingZones.entries.toList().reversed.map((entry) {
                    final summary = _zoneSummary[entry.key];
                    final available = summary?['availableSpots'] ?? '-';
                    final total = summary?['totalSpots'] ?? '-';
                    return _buildSummaryRow(
                      entry.value,
                      summary == null ? '로딩 중...' : '$available / $total대 가능',
                    );
                  }),
                  const Divider(height: 32, color: Color(0xFFF2F4F6)),
                  _buildSummaryRow(
                    '총 잔여 주차',
                    _zoneSummary.isEmpty
                        ? '로딩 중...'
                        : '${_zoneSummary.values.fold(0, (sum, z) => sum + (z['availableSpots'] as int? ?? 0))}대',
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

  // 구역 선택 사이드 바
  Widget _buildZoneSelector() {
    return Column(
      children: parkingZones.entries.toList().reversed.map((entry) {
        final isSelected = _selectedZoneId == entry.key;
        return GestureDetector(
          onTap: () => _onZoneChanged(entry.key),
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
                _zoneShortLabel(entry.key),
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF8B95A1),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // 주차 격자 (API 데이터 기반)
  Widget _buildParkingGrid() {
    if (_spots.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            '주차면 정보가 없습니다.',
            style: TextStyle(color: Color(0xFF8B95A1)),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.5,
      ),
      itemCount: _spots.length,
      itemBuilder: (context, index) {
        final spot = _spots[index];
        final bool isOccupied = spot['occupied'] ?? false;
        final String spotNumber = spot['spotNumber'] ?? '';
        final String spotType = spot['spotType'] ?? '';

        return Container(
          decoration: BoxDecoration(
            color: spot['spotStatus'] == 'INACTIVE'
                ? const Color(0xFFD1D6DB)
                : isOccupied
                ? const Color(0xFFFF4D4D)
                : const Color(0xFF2ECC71),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                spotNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              if (spotType == 'DISABLED')
                const Icon(Icons.accessible, color: Colors.white, size: 14)
              else if (spotType == 'EV')
                const Icon(Icons.electric_car, color: Colors.white, size: 14),
            ],
          ),
        );
      },
    );
  }

  // 범례
  Widget _buildLegend() {
    return Row(
      children: [
        _legendItem(const Color(0xFF2ECC71), '가능'),
        const SizedBox(width: 12),
        _legendItem(const Color(0xFFFF4D4D), '만차'),
        const SizedBox(width: 12),
        _legendItem(const Color(0xFFD1D6DB), '비활성'),
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

  // 요약 행
  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal
                  ? const Color(0xFF191F28)
                  : const Color(0xFF4E5968),
            ),
          ),
          Text(
            value,
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
