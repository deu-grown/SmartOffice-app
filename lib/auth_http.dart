import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'LoginScreen.dart';

/// 전역 네비게이터 키. 세션 만료 시 화면 컨텍스트 없이 로그인 화면으로 보내기 위해
/// MaterialApp 의 navigatorKey 로 연결한다.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// 인증이 필요한 모든 백엔드 호출의 단일 진입점.
///
/// - Authorization: Bearer 액세스 토큰 자동 첨부
/// - 401 응답 시 refresh 토큰으로 1회 재발급 후 재시도
///   (동시에 발생한 401 들은 단일 refresh Future 를 공유해 중복 재발급 방지)
/// - refresh 실패 시 토큰을 삭제하고 로그인 화면으로 이동(세션 만료 일원화)
///
/// 기존 화면의 응답 처리(statusCode / body 파싱)를 그대로 쓰도록 http.Response 를 반환한다.
class AuthHttp {
  AuthHttp._();
  static final AuthHttp instance = AuthHttp._();

  static const String baseUrl = 'https://api.sjparkx1129.com';
  static const String accessTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';

  final http.Client _client = http.Client();

  // 진행 중인 refresh. null 이면 미진행. 동시 401 들이 같은 Future 를 공유한다.
  Future<String?>? _refreshing;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        'accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<String?> _accessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(accessTokenKey);
  }

  // ─────────────────────────────────────────────
  // 공개 메서드 (path 는 '/api/v1/...' 형식, 쿼리스트링 포함 가능)
  // ─────────────────────────────────────────────

  Future<http.Response> get(String path) =>
      _send((token) => _client.get(_uri(path), headers: _headers(token)));

  Future<http.Response> post(String path, {Object? body}) => _send(
        (token) => _client.post(
          _uri(path),
          headers: _headers(token),
          body: body == null ? null : jsonEncode(body),
        ),
      );

  Future<http.Response> put(String path, {Object? body}) => _send(
        (token) => _client.put(
          _uri(path),
          headers: _headers(token),
          body: body == null ? null : jsonEncode(body),
        ),
      );

  Future<http.Response> delete(String path, {Object? body}) => _send(
        (token) => _client.delete(
          _uri(path),
          headers: _headers(token),
          body: body == null ? null : jsonEncode(body),
        ),
      );

  // ─────────────────────────────────────────────
  // 내부: 401 시 refresh + 재시도
  // ─────────────────────────────────────────────

  Future<http.Response> _send(
    Future<http.Response> Function(String? token) call,
  ) async {
    final token = await _accessToken();
    final http.Response res = await call(token);
    if (res.statusCode != 401) return res;

    // 액세스 토큰 만료 → 재발급 1회 후 재시도
    final newToken = await _refreshOnce();
    if (newToken == null) {
      await _clearAndRedirect();
      return res; // 원래 401 을 반환하면 화면은 기존 만료 처리 로직을 그대로 탄다
    }
    return call(newToken);
  }

  Future<String?> _refreshOnce() {
    return _refreshing ??=
        _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _doRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString(refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final res = await _client.post(
        _uri('/api/v1/auth/refresh'),
        headers: _headers(null),
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        final newAccess = data?['accessToken'] as String?;
        if (newAccess != null && newAccess.isNotEmpty) {
          await prefs.setString(accessTokenKey, newAccess);
          // refresh 토큰 로테이션 대응: 새 refreshToken 이 오면 갱신
          final newRefresh = data?['refreshToken'] as String?;
          if (newRefresh != null && newRefresh.isNotEmpty) {
            await prefs.setString(refreshTokenKey, newRefresh);
          }
          return newAccess;
        }
      }
    } catch (_) {
      // 네트워크 예외 등 → 재발급 실패로 처리
    }
    return null;
  }

  Future<void> _clearAndRedirect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(accessTokenKey);
    await prefs.remove(refreshTokenKey);
    final nav = appNavigatorKey.currentState;
    if (nav != null) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
