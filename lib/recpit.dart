import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  static const String _baseUrl = 'https://api.sjparkx1129.com';

  bool _isLoading = true;
  String _errorMessage = '';

  // API에서 받아온 급여 목록
  List<Map<String, dynamic>> _salaryRecords = [];

  // 현재 선택된 급여 인덱스
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchSalaryRecords();
  }

  // ─────────────────────────────────────────────
  // 내 급여 내역 조회
  // ─────────────────────────────────────────────

  // 한 번에 조회할 최근 개월 수 (현재 달 포함)
  static const int _monthsToFetch = 6;

  Future<void> _fetchSalaryRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = '로그인이 필요합니다.';
          _isLoading = false;
        });
        return;
      }

      // 최근 N개월(현재 달부터 역순) (year, month) 리스트 생성
      final now = DateTime.now();
      final periods = List<DateTime>.generate(
        _monthsToFetch,
        (i) => DateTime(now.year, now.month - i, 1),
      );

      // 본인 급여 단건 API를 월별로 병렬 호출
      final responses = await Future.wait(
        periods.map((d) {
          final uri = Uri.parse(
            '$_baseUrl/api/v1/salary/records/me?year=${d.year}&month=${d.month}',
          );
          return http.get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
        }),
      );

      if (!mounted) return;

      // 한 건이라도 401이 오면 인증 만료로 처리
      if (responses.any((r) => r.statusCode == 401)) {
        setState(() {
          _errorMessage = '인증이 만료되었습니다. 다시 로그인해주세요.';
          _isLoading = false;
        });
        return;
      }

      // 200 응답만 모아 단건 데이터를 누적 (없는 달은 404 등으로 무시)
      final records = <Map<String, dynamic>>[];
      for (final r in responses) {
        if (r.statusCode == 200) {
          final json = jsonDecode(utf8.decode(r.bodyBytes));
          if (json['code'] == 'success' && json['data'] != null) {
            records.add(Map<String, dynamic>.from(json['data'] as Map));
          }
        }
      }

      setState(() {
        _salaryRecords = records;
        _selectedIndex = 0;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '서버에 연결할 수 없습니다.';
        _isLoading = false;
      });
    }
  }

  // ─────────────────────────────────────────────
  // 유틸
  // ─────────────────────────────────────────────

  String _formatCurrency(int amount) {
    return '${amount.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}원';
  }

  String _monthLabel(Map<String, dynamic> record) {
    return '${record['month']}월';
  }

  String _periodLabel(Map<String, dynamic> record) {
    return '${record['year']}년 ${record['month']}월';
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
          '급여 명세서',
          style: TextStyle(
            color: Color(0xFF191F28),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4E5968)),
            onPressed: _fetchSalaryRecords,
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
                    size: 48,
                    color: Color(0xFFB0B8C1),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage,
                    style: const TextStyle(
                      color: Color(0xFF8B95A1),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _fetchSalaryRecords,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 248, 193, 43),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            )
          : _salaryRecords.isEmpty
          ? const Center(
              child: Text(
                '급여 내역이 없습니다.',
                style: TextStyle(color: Color(0xFF8B95A1), fontSize: 15),
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final current = _salaryRecords[_selectedIndex];
    final int baseSalary = current['baseSalary'] ?? 0;
    final int overtimePay = current['overtimePay'] ?? 0;
    final int totalPay = current['totalPay'] ?? 0;

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── 월 셀렉터 ──
          Container(
            color: Colors.white,
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _salaryRecords.length,
              itemBuilder: (context, index) {
                final record = _salaryRecords[index];
                final isSelected = _selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIndex = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color.fromARGB(255, 248, 193, 43)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: isSelected
                            ? null
                            : Border.all(color: const Color(0xFFE5E8EB)),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color.fromARGB(
                                    255,
                                    248,
                                    193,
                                    43,
                                  ).withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _monthLabel(record),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF8B95A1),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 기간 타이틀 + 실 지급액 ──
                Text(
                  '${_periodLabel(current)} 명세서',
                  style: const TextStyle(
                    color: Color(0xFF8B95A1),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '실 지급액',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF191F28),
                          ),
                        ),
                        Text(
                          _formatCurrency(totalPay),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 248, 193, 43),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F3FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.credit_card,
                        color: Color.fromARGB(255, 248, 193, 43),
                        size: 32,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── 급여 상태 배지 ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: current['status'] == 'CONFIRMED'
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    current['status'] == 'CONFIRMED' ? '확정' : '산출 중',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: current['status'] == 'CONFIRMED'
                          ? const Color(0xFF2ECC71)
                          : const Color(0xFFFFB800),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── 지급 수당 ──
                _buildDetailSection('지급 수당', [
                  {'label': '기본급', 'value': baseSalary},
                  {'label': '초과근무수당', 'value': overtimePay},
                ], false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildGridItem(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8B95A1),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color ?? const Color(0xFF333D4B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(
    String title,
    List<Map<String, dynamic>> items,
    bool isNegative,
  ) {
    final int total = items.fold(
      0,
      (sum, item) => sum + (item['value'] as int),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333D4B),
            ),
          ),
        ),
        _buildSectionCard(
          child: Column(
            children: [
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item['label'],
                        style: const TextStyle(
                          color: Color(0xFF4E5968),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        isNegative
                            ? '- ${_formatCurrency(item['value'])}'
                            : _formatCurrency(item['value']),
                        style: TextStyle(
                          color: isNegative
                              ? const Color(0xFFF04452)
                              : const Color(0xFF333D4B),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Color(0xFFF2F4F6), thickness: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isNegative ? '공제 합계' : '수당 합계',
                    style: TextStyle(
                      color: isNegative
                          ? const Color(0xFFF04452)
                          : const Color(0xFF3182F6),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    isNegative
                        ? '- ${_formatCurrency(total)}'
                        : _formatCurrency(total),
                    style: TextStyle(
                      color: isNegative
                          ? const Color(0xFFF04452)
                          : const Color(0xFF3182F6),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
}
