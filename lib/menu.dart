import 'package:flutter/material.dart';
import 'parking.dart';
import 'temp_control.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {},
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        children: [
          const SizedBox(height: 10),
          const Text(
            '전체',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF191F28),
            ),
          ),
          const SizedBox(height: 32),

          _buildSectionTitle('주요 서비스'),
          _buildListItem('assets/images/image1.png', '주차현황'),
          _buildListItem('assets/images/image2.png', '급여확인'),
          _buildListItem('assets/images/image8.png', '식단표'),

          const SizedBox(height: 32),

          _buildSectionTitle('사무실 제어'),
          _buildListItem('assets/images/image3.png', '온도 습도 조절'),
          _buildListItem('assets/images/image6.png', '조명조절'),
          _buildListItem('assets/images/image4.png', '회의실 예약'),

          const SizedBox(height: 32),

          _buildSectionTitle('인사/근태'),
          _buildListItem('assets/images/image5.png', '근태조회'),
          _buildListItem('assets/images/image7.png', '휴가신청/조회'),

          SizedBox(height: bottomPadding + 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF8B95A1),
        ),
      ),
    );
  }

  Widget _buildListItem(String imagePath, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: InkWell(
        onTap: () {
          if (label == '주차현황') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ParkingScreen()),
            );
          } else if (label == '온도 습도 조절') {
            Navigator.push(
              context,

              MaterialPageRoute(
                builder: (context) => const TempControlScreen(),
              ),
            );
          } else {
            debugPrint('$label 클릭됨');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: Image.asset(imagePath, fit: BoxFit.contain),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333D4B),
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
      ),
    );
  }
}
