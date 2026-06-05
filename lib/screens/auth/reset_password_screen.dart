// lib/screens/auth/reset_password_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
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
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('비밀번호가 변경됐어요! 🎉'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        // 로그인 화면으로 이동
        await Supabase.instance.client.auth.signOut();
      }
    } on AuthException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = '오류가 발생했어요. 다시 시도해주세요.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppColors.tagBg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(child: Text('🔐', style: TextStyle(fontSize: 32))),
              ),
              const SizedBox(height: 24),
              const Text(
                '새 비밀번호 설정',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              const Text(
                '새로운 비밀번호를 입력해주세요',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 36),

              const Text('새 비밀번호', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
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

              const Text('비밀번호 확인', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                style: const TextStyle(fontSize: 15),
                onSubmitted: (_) => _updatePassword(),
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

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
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
                  onPressed: _loading ? null : _updatePassword,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('비밀번호 변경하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
