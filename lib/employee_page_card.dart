import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'menu.dart'; // 기존 메뉴 파일 임포트 유지

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _employeeImage;
  String _currentTime = "";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer t) => _updateTime(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    setState(() {
      _currentTime = DateFormat('yyyy년 M월 d일 HH:mm:ss').format(DateTime.now());
    });
  }

  Future<void> _pickImageFromGallery() async {
    var status = await Permission.photos.request();
    if (status.isGranted) {
      final XFile? pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        setState(() {
          _employeeImage = File(pickedFile.path);
        });
      }
    } else {
      // 권한 거부 처리 로직 (기존과 동일)
      openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6), // 토스 배경색 (연한 회색)
      appBar: AppBar(
        title: const Text(
          '사원증',
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
          icon: const Icon(Icons.menu, color: Color(0xFF4E5968)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MenuScreen()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4E5968)),
            onPressed: _updateTime,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // 메인 사원증 카드
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // 1. 사원 사진 영역 (둥근 사각형 프레임)
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 200,
                        height: 260,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFF2F4F6),
                            width: 1,
                          ),
                        ),
                        child: _employeeImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.file(
                                  _employeeImage!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.person,
                                  size: 80,
                                  color: Color(0xFFD1D6DB),
                                ),
                              ),
                      ),
                      // 사진 추가 버튼 (토스 스타일 플러스 버튼)
                      GestureDetector(
                        onTap: _pickImageFromGallery,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color.fromARGB(
                              255,
                              248,
                              193,
                              43,
                            ), //orange color
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // 2. 이름 및 직급
                  const Text(
                    '곽순호 과장',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF191F28),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '기획부 · 38714',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF8B95A1),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 하단 구분선
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    color: const Color(0xFFF2F4F6),
                  ),

                  // 3. 실시간 시간 표시 영역
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Column(
                      children: [
                        const Text(
                          '현재 시간',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB0B8C1),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _currentTime,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4E5968),
                            fontFamily: 'monospace', // 시간 숫자가 흔들리지 않게 함
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
