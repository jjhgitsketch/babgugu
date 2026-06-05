// lib/main.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_screen.dart';
import 'models/models.dart';
import 'services/supabase_service.dart';

import 'map_init_stub.dart'
    if (dart.library.io) 'map_init_native.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://uhclywphhbirymmejkyf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVoY2x5d3BoaGJpcnltbWVqa3lmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM2MjA1ODAsImV4cCI6MjA4OTE5NjU4MH0.yqwdqb8SyU_EYDnKQZ-mCza6lCo58F8sv9-Ph0JMRC8',
  );

  if (!kIsWeb) {
    await initNaverMap();
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const MealMateApp());
}

class MealMateApp extends StatelessWidget {
  const MealMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '밥메이트',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _loading = true;
  bool _isPasswordReset = false;

  @override
  void initState() {
    super.initState();

    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      // ① passwordRecovery 이벤트 → 즉시 재설정 화면
      if (event == AuthChangeEvent.passwordRecovery) {
        if (mounted) setState(() { _isPasswordReset = true; _loading = false; });
        return;
      }

      // ② 딥링크(io.supabase.mealmate://reset-callback)로 앱 복귀 시
      //    Supabase는 signedIn 이벤트를 발생시키지만
      //    session.user.recoverySentAt 또는 amr 클레임으로 recovery 플로우 감지
      if (event == AuthChangeEvent.signedIn && session != null) {
        final isRecovery = _isRecoverySession(session);
        if (isRecovery) {
          if (mounted) setState(() { _isPasswordReset = true; _loading = false; });
          return;
        }
        await SupabaseService.loadCurrentUser(session.user.id);
        if (mounted) setState(() { _isPasswordReset = false; _loading = false; });
        return;
      }

      if (event == AuthChangeEvent.signedOut) {
        currentUser = null;
        if (mounted) setState(() { _isPasswordReset = false; _loading = false; });
      } else if (event == AuthChangeEvent.initialSession) {
        if (session != null) {
          // 앱 재시작 시 recovery 세션이면 바로 재설정 화면으로
          if (_isRecoverySession(session)) {
            if (mounted) setState(() { _isPasswordReset = true; _loading = false; });
            return;
          }
          bool loaded = false;
          for (int i = 0; i < 3; i++) {
            loaded = await SupabaseService.loadCurrentUser(session.user.id);
            if (loaded) break;
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  /// recoverySentAt 기반으로 비밀번호 재설정 세션 여부 확인
  bool _isRecoverySession(Session session) {
    try {
      final raw = session.user.recoverySentAt;
      if (raw == null) return false;
      // supabase_flutter 2.x에서 recoverySentAt은 String으로 반환됨
      final sentAt = DateTime.parse(raw.toString()).toUtc();
      final diff = DateTime.now().toUtc().difference(sentAt).abs();
      return diff.inMinutes < 10;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🍽️', style: TextStyle(fontSize: 48)),
              SizedBox(height: 16),
              CircularProgressIndicator(color: AppColors.primary),
            ],
          ),
        ),
      );
    }

    if (_isPasswordReset) return const ResetPasswordScreen();

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return const LoginScreen();
    if (currentUser == null) return const OnboardingScreen();
    return const MainScreen();
  }
}
