import 'package:flutter/material.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class SalaryData {
  final String period;
  final String monthLabel;
  final Map<String, String> employee;
  final List<Map<String, dynamic>> pay;
  final List<Map<String, dynamic>> deductions;
  final int netPay;

  SalaryData({
    required this.period,
    required this.monthLabel,
    required this.employee,
    required this.pay,
    required this.deductions,
    required this.netPay,
  });
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  String selectedMonth = '4월';

  final List<SalaryData> _allData = [
    SalaryData(
      monthLabel: '4월',
      period: '2026년 4월',
      employee: {
        'name': '김고은',
        'dept': '기획부',
        'id': '037128',
        'pos': '대리',
        'hours': '208 H',
        'over': '12 H',
        'vac': '1d',
      },
      pay: [
        {'label': '기본금', 'value': 1950000},
        {'label': '초과근무', 'value': 120000},
        {'label': '주휴수당', 'value': 280000},
      ],
      deductions: [
        {'label': '국민연금', 'value': 180000},
        {'label': '소득세', 'value': 142000},
        {'label': '건강보험', 'value': 100000},
      ],
      netPay: 1928000,
    ),
    SalaryData(
      monthLabel: '3월',
      period: '2026년 3월',
      employee: {
        'name': '김고은',
        'dept': '기획부',
        'id': '037128',
        'pos': '대리',
        'hours': '220 H',
        'over': '32 H',
        'vac': '3d',
      },
      pay: [
        {'label': '기본금', 'value': 1950000},
        {'label': '초과근무', 'value': 320000},
        {'label': '주휴수당', 'value': 280000},
      ],
      deductions: [
        {'label': '국민연금', 'value': 180000},
        {'label': '소득세', 'value': 158000},
        {'label': '건강보험', 'value': 100000},
      ],
      netPay: 2112000,
    ),
    SalaryData(
      monthLabel: '2월',
      period: '2026년 2월',
      employee: {
        'name': '김고은',
        'dept': '기획부',
        'id': '037128',
        'pos': '대리',
        'hours': '160 H',
        'over': '0 H',
        'vac': '2d',
      },
      pay: [
        {'label': '기본금', 'value': 1950000},
        {'label': '초과근무', 'value': 0},
        {'label': '주휴수당', 'value': 280000},
      ],
      deductions: [
        {'label': '국민연금', 'value': 180000},
        {'label': '소득세', 'value': 130000},
        {'label': '건강보험', 'value': 100000},
      ],
      netPay: 1820000,
    ),
  ];

  String _formatCurrency(int amount) {
    return '${amount.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}원';
  }

  @override
  Widget build(BuildContext context) {
    final currentData = _allData.firstWhere(
      (element) => element.monthLabel == selectedMonth,
    );

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
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Month Selector
            Container(
              color: Colors.white,
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _allData.length,
                itemBuilder: (context, index) {
                  final m = _allData[index];
                  final isSelected = selectedMonth == m.monthLabel;
                  return Padding(
                    padding: const EdgeInsets.only(
                      right: 8,
                      top: 10,
                      bottom: 10,
                    ),
                    child: GestureDetector(
                      onTap: () => setState(() => selectedMonth = m.monthLabel),
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
                          m.monthLabel,
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
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionBtn(
                          Icons.file_download_outlined,
                          'PDF저장',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionBtn(Icons.print_outlined, '명세서인쇄'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Period Title
                  Text(
                    '${currentData.period} 명세서',
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
                            _formatCurrency(currentData.netPay),
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
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F3FF),
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
                  const SizedBox(height: 24),

                  // Employee Info Card
                  _buildSectionCard(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF2F4F6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '👤',
                                      style: TextStyle(fontSize: 20),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '사원 정보',
                                      style: TextStyle(
                                        color: Color(0xFF8B95A1),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${currentData.employee['name']} ${currentData.employee['pos']}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF333D4B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  '사번',
                                  style: TextStyle(
                                    color: Color(0xFF8B95A1),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  currentData.employee['id']!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF333D4B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Divider(
                            color: Color(0xFFF2F4F6),
                            thickness: 1,
                          ),
                        ),
                        _buildInfoGrid(currentData.employee),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Pay Details
                  _buildDetailSection('지급 수당', currentData.pay, false),
                  const SizedBox(height: 32),

                  // Deduction Details
                  _buildDetailSection('공제 금액', currentData.deductions, true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E8EB)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4E5968)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF4E5968),
              fontWeight: FontWeight.bold,
              fontSize: 14,
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

  Widget _buildInfoGrid(Map<String, String> emp) {
    return Column(
      children: [
        Row(
          children: [
            _buildGridItem('부서', emp['dept']!),
            _buildGridItem('총 근무시간', emp['hours']!),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildGridItem(
              '초과근무',
              emp['over']!,
              color: const Color(0xFF3182F6),
            ),
            _buildGridItem('사용휴가', emp['vac']!, color: const Color(0xFFFFB800)),
          ],
        ),
      ],
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
    int total = items.fold(0, (sum, item) => sum + (item['value'] as int));
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

  Widget _buildInfoBanner(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF2F4F7),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF8B95A1), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF333D4B),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Color(0xFFD1D6DB),
          ),
        ],
      ),
    );
  }
}
