import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'employee_page_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  static const String _baseUrl = 'http://10.0.2.2:8080';

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // 토큰 저장/조회 유틸
  // ─────────────────────────────────────────────

  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<String?> _getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  Future<void> _saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
  }

  // ─────────────────────────────────────────────
  // Access Token 재발급
  // ─────────────────────────────────────────────

  /// Refresh Token으로 새 Access Token을 발급받는다.
  /// 실패하면 null 반환 → 로그인 화면으로 이동.
  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken = data['data']['accessToken'] as String?;
        if (newAccessToken != null) {
          await _saveAccessToken(newAccessToken);
          return newAccessToken;
        }
      }
    } catch (_) {}

    return null;
  }

  // ─────────────────────────────────────────────
  // 공통 인증 API 요청 (401 시 자동 재발급)
  // ─────────────────────────────────────────────

  Future<http.Response> apiRequest({
    required Future<http.Response> Function(String accessToken) call,
  }) async {
    String? token = await _getAccessToken();
    if (token == null || token.isEmpty) {
      _goToLogin();
      return http.Response('{"message":"unauthorized"}', 401);
    }

    // 1차 시도
    http.Response response = await call(token);

    // Access Token 만료 → 재발급 후 재시도
    if (response.statusCode == 401) {
      final newToken = await _refreshAccessToken();

      if (newToken == null) {
        // Refresh Token도 만료 → 로그아웃
        await _clearTokens();
        _goToLogin();
        return http.Response('{"message":"session_expired"}', 401);
      }

      // 새 토큰으로 재시도
      response = await call(newToken);
    }

    return response;
  }

  // ─────────────────────────────────────────────
  // 로그인 화면으로 이동
  // ─────────────────────────────────────────────

  void _goToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  // ─────────────────────────────────────────────
  // 로그인
  // ─────────────────────────────────────────────

  Future<void> _login() async {
    final String email = _idController.text.trim();
    final String password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이메일과 비밀번호를 입력해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/auth/login'),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // 토큰 저장
        final String? accessToken = responseData['data']['accessToken'];
        final String? refreshToken = responseData['data']['refreshToken'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', accessToken ?? '');
        await prefs.setString('refresh_token', refreshToken ?? '');

        // 로그인 성공 후 홈 화면으로 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        String errorMessage = '아이디 또는 비밀번호가 틀렸습니다.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('서버에 연결할 수 없습니다. 네트워크를 확인해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: screenHeight * 0.05),

                // 1. ID(이메일) 입력 필드
                TextField(
                  controller: _idController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue, width: 2.0),
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),

                // 2. Password 입력 필드
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue, width: 2.0),
                    ),
                  ),
                  onSubmitted: (_) => _login(),
                ),

                // 3. 아이디 / 비밀번호 찾기
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            title: const Text(
                              '안내',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            content: const Text('관리자에게 문의하십시오.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text(
                                  '확인',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '아이디 / 비밀번호 찾기',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.06),

                // 4. 로그인 버튼
                Center(
                  child: SizedBox(
                    width: screenWidth * 0.6,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4D4D4D),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'LOGIN',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.05),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
