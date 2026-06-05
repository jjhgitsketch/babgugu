// lib/screens/auth/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    // 유효성 검사
    if (_emailController.text.trim().isEmpty) {
      setState(() => _error = '이메일을 입력해주세요');
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _error = '비밀번호는 6자 이상이어야 해요');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = '비밀번호가 일치하지 않아요');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // 회원가입 성공 → _AuthGate의 onAuthStateChange가 자동으로 온보딩으로 이동
      // 별도 Navigator 불필요
    } on AuthException catch (e) {
      setState(() => _error = _translateError(e.message));
    } catch (e) {
      setState(() => _error = '오류가 발생했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _translateError(String msg) {
    if (msg.contains('already registered')) return '이미 가입된 이메일이에요';
    if (msg.contains('invalid email')) return '올바른 이메일 형식이 아니에요';
    if (msg.contains('Password should be')) return '비밀번호는 6자 이상이어야 해요';
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('회원가입', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -1)),
              const SizedBox(height: 8),
              const Text('밥메이트에 오신 걸 환영해요!', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
              const SizedBox(height: 40),

              // 이메일
              const Text('이메일', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'example@email.com',
                  prefixIcon: Icon(Icons.email_outlined, size: 20, color: AppColors.textLight),
                ),
              ),
              const SizedBox(height: 16),

              // 비밀번호
              const Text('비밀번호', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: '6자 이상 입력해주세요',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppColors.textLight),
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20, color: AppColors.textLight),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 비밀번호 확인
              const Text('비밀번호 확인', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                style: const TextStyle(fontSize: 15),
                onSubmitted: (_) => _signup(),
                decoration: InputDecoration(
                  hintText: '비밀번호를 한번 더 입력해주세요',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppColors.textLight),
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    child: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20, color: AppColors.textLight),
                  ),
                ),
              ),

              // 에러 메시지
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: Colors.red))),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signup,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('가입하기'),
                ),
              ),
              const SizedBox(height: 20),

              // 약관
              const Center(
                child: Text(
                  '가입 시 이용약관 및 개인정보처리방침에 동의하게 됩니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.textLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
