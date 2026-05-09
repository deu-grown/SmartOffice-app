import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // SharedPreferences 추가

import 'menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _employeeImage;
  String _currentTime = "";
  Timer? _timer;

  // API 연동을 위한 상태 변수
  bool _isLoading = true;
  String _name = "";
  String _position = "";
  String _department = "";
  String _employeeNumber = "";

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer t) => _updateTime(),
    );

    // 화면 진입 시 내 데이터 불러오기
    _fetchMyProfileData();
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

  // 🌟 내 정보 조회(직원) API 연동 - SharedPreferences 토큰 사용 🌟
  Future<void> _fetchMyProfileData() async {
    setState(() => _isLoading = true);

    try {
      // 1. SharedPreferences에서 로그인 시 저장한 토큰 꺼내기
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      // 토큰이 없는 경우 예외 처리 (로그인이 풀린 경우 등)
      if (token == null || token.isEmpty) {
        print('저장된 토큰이 없습니다. 다시 로그인해주세요.');
        _setDefaultData();
        return;
      }

      // 2. 로그인 화면과 동일한 호스트(10.0.2.2) 사용
      final url = Uri.parse('http://10.0.2.2:8080/api/v1/users/me');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // 꺼낸 토큰을 헤더에 삽입
        },
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final json = jsonDecode(decodedBody);

        if (json['code'] == 'success') {
          final data = json['data'];
          setState(() {
            _name = data['name'] ?? '이름 없음';
            _position = data['position'] ?? '';
            _department = data['department'] ?? '부서 미정';
            _employeeNumber = data['employeeNumber'] ?? '-';
            _isLoading = false;
          });
        } else {
          print('API 오류 메시지: ${json['message']}');
          _setDefaultData();
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
        _setDefaultData();
      }
    } catch (e) {
      print('Network Error: $e');
      _setDefaultData();
    }
  }

  // API 호출 실패 시 에러 화면 처리를 위한 함수
  void _setDefaultData() {
    setState(() {
      _name = "정보 불러오기 실패";
      _position = "";
      _department = "-";
      _employeeNumber = "-";
      _isLoading = false;
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
      openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
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
            onPressed: () {
              // 새로고침 시 시간과 사원 정보 다시 로드
              _updateTime();
              _fetchMyProfileData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4E5968)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
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
                            GestureDetector(
                              onTap: _pickImageFromGallery,
                              child: Container(
                                margin: const EdgeInsets.all(8),
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color.fromARGB(255, 248, 193, 43),
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

                        // API 데이터 바인딩
                        Text(
                          '$_name $_position',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF191F28),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_department · $_employeeNumber',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF8B95A1),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 40),

                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          color: const Color(0xFFF2F4F6),
                        ),

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
                                  fontFamily: 'monospace',
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
