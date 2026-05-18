import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SensorZoneData {
  final int zoneId;
  final String zoneName;
  final double? temp;
  final double? humi;
  final double? co2;
  final String? updatedAt;

  SensorZoneData({
    required this.zoneId,
    required this.zoneName,
    this.temp,
    this.humi,
    this.co2,
    this.updatedAt,
  });

  factory SensorZoneData.fromJson(Map<String, dynamic> json) {
    return SensorZoneData(
      zoneId: json['zoneId'] as int,
      zoneName: json['zoneName'] as String,
      temp: json['temp'] != null ? (json['temp'] as num).toDouble() : null,
      humi: json['humi'] != null ? (json['humi'] as num).toDouble() : null,
      co2: json['co2'] != null ? (json['co2'] as num).toDouble() : null,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class TempControlScreen extends StatefulWidget {
  const TempControlScreen({super.key});

  @override
  State<TempControlScreen> createState() => _TempControlScreenState();
}

class _TempControlScreenState extends State<TempControlScreen> {
  static const String _baseUrl = 'http://10.0.2.2:8080';

  List<SensorZoneData> _zones = [];
  int _selectedIndex = 0;
  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchSensorData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchSensorData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchSensorData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = '로그인이 필요합니다.';
            _isLoading = false;
          });
        }
        return;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/dashboard/sensors/current'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final json = jsonDecode(decodedBody);

        if (json['code'] == 'success') {
          final List<dynamic> dataList = json['data'] ?? [];
          setState(() {
            _zones = dataList
                .map((e) => SensorZoneData.fromJson(e as Map<String, dynamic>))
                .toList();
            if (_selectedIndex >= _zones.length && _zones.isNotEmpty) {
              _selectedIndex = 0;
            }
            _isLoading = false;
            _errorMessage = '';
          });
        } else {
          setState(() {
            _errorMessage = '데이터를 불러올 수 없습니다.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = '서버 오류가 발생했습니다. (${response.statusCode})';
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

  String _formatUpdatedAt(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.month}/${dt.day} $h:$m 기준';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: AppBar(
        title: const Text(
          '실내 온·습도 조회',
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
              _fetchSensorData();
            },
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
                      _fetchSensorData();
                    },
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            )
          : _zones.isEmpty
          ? const Center(
              child: Text(
                '센서 데이터가 없습니다.',
                style: TextStyle(color: Color(0xFF8B95A1), fontSize: 15),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LIVE 배지
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Row(
                      children: [
                        const Text(
                          '공간 선택',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4E5968),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                  ),
                  const SizedBox(height: 12),

                  // 구역 선택 가로 스크롤
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: List.generate(_zones.length, _buildZoneChip),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: _buildSensorCard(_zones[_selectedIndex]),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildZoneChip(int index) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
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
          _zones[index].zoneName,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF4E5968),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSensorCard(SensorZoneData zone) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildSensorRow(
            '현재 온도',
            zone.temp != null ? '${zone.temp!.toStringAsFixed(1)}°C' : '-',
            Icons.thermostat,
            Colors.orange,
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF2F4F6)),
          const SizedBox(height: 16),
          _buildSensorRow(
            '현재 습도',
            zone.humi != null ? '${zone.humi!.toStringAsFixed(1)}%' : '-',
            Icons.water_drop,
            Colors.blue,
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF2F4F6)),
          const SizedBox(height: 16),
          _buildSensorRow(
            'CO₂',
            zone.co2 != null ? '${zone.co2!.toStringAsFixed(0)} ppm' : '-',
            Icons.air,
            Colors.green,
          ),
          if (zone.updatedAt != null) ...[
            const SizedBox(height: 20),
            Text(
              _formatUpdatedAt(zone.updatedAt),
              style: const TextStyle(
                color: Color(0xFF8B95A1),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSensorRow(String label, String value, IconData icon, Color color) {
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
}
