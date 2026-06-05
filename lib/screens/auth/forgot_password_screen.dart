// lib/screens/auth/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = '이메일을 입력해주세요');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.mealmate://reset-callback',
      );
      setState(() { _sent = true; _loading = false; });
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
    if (msg.contains('User not found')) return '가입되지 않은 이메일이에요';
    if (msg.contains('rate limit')) return '잠시 후 다시 시도해주세요';
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
          child: _sent ? _SentView(
            email: _emailController.text.trim(),
            onBack: () => Navigator.pop(context),
          ) : _InputView(
            emailController: _emailController,
            loading: _loading,
            error: _error,
            onSend: _sendResetEmail,
          ),
        ),
      ),
    );
  }
}

// ─── 이메일 입력 화면 ───
class _InputView extends StatelessWidget {
  final TextEditingController emailController;
  final bool loading;
  final String? error;
  final VoidCallback onSend;

  const _InputView({
    required this.emailController,
    required this.loading,
    required this.error,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        // 아이콘
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.tagBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(
            child: Text('🔑', style: TextStyle(fontSize: 32)),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '비밀번호 재설정',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '가입한 이메일을 입력하면\n비밀번호 재설정 링크를 보내드려요',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 36),

        const Text(
          '이메일',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          style: const TextStyle(fontSize: 15),
          onSubmitted: (_) => onSend(),
          decoration: const InputDecoration(
            hintText: 'example@email.com',
            prefixIcon: Icon(Icons.email_outlined, size: 20, color: AppColors.textLight),
          ),
        ),

        // 에러
        if (error != null) ...[
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
                Expanded(child: Text(error!, style: const TextStyle(fontSize: 13, color: Colors.red))),
              ],
            ),
          ),
        ],

        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: loading ? null : onSend,
            child: loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('재설정 링크 보내기'),
          ),
        ),
      ],
    );
  }
}

// ─── 전송 완료 화면 ───
class _SentView extends StatelessWidget {
  final String email;
  final VoidCallback onBack;

  const _SentView({required this.email, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(
            child: Text('📧', style: TextStyle(fontSize: 32)),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '이메일을 확인해주세요!',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5),
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.6),
            children: [
              TextSpan(
                text: email,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const TextSpan(text: ' 으로\n비밀번호 재설정 링크를 보냈어요.\n메일함을 확인해주세요!'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 안내
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.tagBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text('메일이 안 보이면?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),
              SizedBox(height: 6),
              Text(
                '• 스팸함을 확인해주세요\n• 1~2분 정도 기다려보세요\n• 이메일 주소가 맞는지 확인해주세요',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onBack,
            child: const Text('로그인으로 돌아가기'),
          ),
        ),
      ],
    );
  }
}
