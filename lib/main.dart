import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🌟 1. 세로 고정을 위해 추가된 패키지
import 'LoginScreen.dart'; // 🌟 방금 우리가 만든 로그인 화면 부품을 불러옵니다!

// 앱의 진입점 (여기서부터 앱이 시작됩니다)
void main() async {
  // 🌟 2. 설정이 끝날 때까지 기다리도록 async를 추가
  // 🌟 3. 방향 설정 전에 플러터 엔진이 초기화되었는지 확실히 체크!
  WidgetsFlutterBinding.ensureInitialized();

  // 🌟 4. 기기의 방향을 세로(위, 아래)로만 고정합니다.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 설정이 모두 끝난 후 앱을 실행합니다.
  runApp(const SmartOfficeApp());
}

class SmartOfficeApp extends StatelessWidget {
  const SmartOfficeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 우측 상단 'DEBUG' 띠 제거
      title: 'Smart Office AC', // 앱 이름
      theme: ThemeData(
        primarySwatch: Colors.blue, // 앱의 기본 테마 색상
        scaffoldBackgroundColor: Colors.white,
      ),
      // 🌟 앱을 켜자마자 가장 먼저 보여줄 화면을 LoginScreen으로 지정합니다!
      home: const LoginScreen(),
    );
  }
}
