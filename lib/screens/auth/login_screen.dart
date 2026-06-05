// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  // 레퍼런스 이미지 색상
  static const _pink = Color(0xFFE8A598);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _error = '이메일과 비밀번호를 입력해주세요');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on AuthException catch (e) {
      setState(() {
        _error = _translateError(e.message);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '오류가 발생했어요. 다시 시도해주세요.';
        _loading = false;
      });
    }
  }

  String _translateError(String msg) {
    if (msg.contains('Invalid login')) return '이메일 또는 비밀번호가 틀렸어요';
    if (msg.contains('Email not confirmed')) return '이메일 인증이 필요해요. 메일함을 확인해주세요';
    if (msg.contains('too many requests')) return '잠시 후 다시 시도해주세요';
    return msg;
  }

  // 입력창 스타일
  InputDecoration _inputDecoration({
    required String hint,
    required IconData suffixIcon,
    Widget? customSuffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 15),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      suffixIcon: customSuffix ?? Icon(suffixIcon, color: _pink, size: 22),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _pink, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              // 로고 영역
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _pink.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '🍽️',
                    style: const TextStyle(fontSize: 44),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'BabGuGu',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _pink,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 48),

              // 서브타이틀
              const Text(
                '로그인하고 밥메이트를 만나보세요',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 32),

              // 이메일 레이블
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  '이메일',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
                decoration: _inputDecoration(
                  hint: 'example@email.com',
                  suffixIcon: Icons.mail_outline_rounded,
                ),
              ),
              const SizedBox(height: 16),

              // 비밀번호 레이블
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  '비밀번호',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
                onSubmitted: (_) => _login(),
                decoration: _inputDecoration(
                  hint: '비밀번호를 입력해주세요',
                  suffixIcon: Icons.lock_outline_rounded,
                  customSuffix: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(
                      _obscure
                          ? Icons.lock_outline_rounded
                          : Icons.lock_open_rounded,
                      color: _pink,
                      size: 22,
                    ),
                  ),
                ),
              ),

              // 비밀번호 찾기
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen())),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      '비밀번호를 잊으셨나요?',
                      style: TextStyle(
                        fontSize: 13,
                        color: _pink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // 에러
              if (_error != null) ...[
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.red))),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // 로그인 버튼 (검은색)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text(
                          '로그인',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // 회원가입
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SignupScreen())),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 14, color: Color(0xFF888888)),
                    children: [
                      TextSpan(text: '아직 계정이 없으신가요?  '),
                      TextSpan(
                        text: '회원가입',
                        style: TextStyle(
                            color: _pink, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
