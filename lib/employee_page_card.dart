import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'menu.dart';
import 'LoginScreen.dart';
import 'auth_http.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _employeeImage;
  String _currentTime = "";
  Timer? _timer;

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

  // ─────────────────────────────────────────────
  // 로그인 화면으로 이동 (뒤로가기 불가)
  // ─────────────────────────────────────────────

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  // ─────────────────────────────────────────────
  // 내 정보 조회
  // ─────────────────────────────────────────────

  Future<void> _fetchMyProfileData() async {
    setState(() => _isLoading = true);

    try {
      final response = await AuthHttp.instance.get('/api/v1/users/me');

      // 인증 실패 시 로그인 화면으로
      if (response.statusCode == 401 || response.statusCode == 403) {
        _goToLogin();
        return;
      }

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
          _goToLogin();
        }
      } else {
        _goToLogin();
      }
    } catch (e) {
      // 네트워크 오류 → 로그인으로
      _goToLogin();
    }
  }

  // ─────────────────────────────────────────────
  // 로그아웃 (확인 없이 바로 처리)
  // ─────────────────────────────────────────────

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? refreshToken = prefs.getString('refresh_token');

      // 서버에 로그아웃 요청 (액세스 토큰은 AuthHttp 가 자동 첨부)
      if (refreshToken != null) {
        await AuthHttp.instance.post(
          '/api/v1/auth/logout',
          body: {'refreshToken': refreshToken},
        );
      }
    } catch (_) {
      // 서버 요청 실패해도 로컬 토큰 삭제 후 로그인으로
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('refresh_token');
      _goToLogin();
    }
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

                  const SizedBox(height: 16),

                  // ─── 로그아웃 버튼 (토스 스타일) ───
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0F0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.logout_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Text(
                            '로그아웃',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF191F28),
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFFB0B8C1),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
