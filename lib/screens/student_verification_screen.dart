// lib/screens/student_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class StudentVerificationScreen extends StatefulWidget {
  const StudentVerificationScreen({super.key});

  @override
  State<StudentVerificationScreen> createState() =>
      _StudentVerificationScreenState();
}

class _StudentVerificationScreenState extends State<StudentVerificationScreen> {
  static const _allowedDomains = ['cau.ac.kr', 'm365.cau.ac.kr'];

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  String? _message;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = currentUser?.schoolEmail ??
        Supabase.instance.client.auth.currentUser?.email ??
        '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim().toLowerCase();

  bool get _isAllowedSchoolEmail {
    final parts = _email.split('@');
    if (parts.length != 2 || parts.first.isEmpty || parts.last.isEmpty) {
      return false;
    }
    return _allowedDomains.contains(parts.last);
  }

  Future<void> _sendCode() async {
    if (!_isAllowedSchoolEmail) {
      _showMessage(
        '중앙대학교 학교 이메일만 인증할 수 있어요. @cau.ac.kr 또는 @m365.cau.ac.kr 주소를 입력해 주세요.',
        isError: true,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await SupabaseService.sendSchoolEmailOtp(_email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _message = '인증 메일을 보냈어요. 메일함에 도착한 6자리 코드를 입력해 주세요.';
        _isError = false;
      });
    } catch (e) {
      _showMessage(_translateVerificationError(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final token = _codeController.text.trim();
    if (token.length < 6) {
      _showMessage('인증 코드 6자리를 입력해 주세요.', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await SupabaseService.verifySchoolEmailOtp(email: _email, token: token);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showMessage(_translateVerificationError(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _isError = isError;
    });
  }

  String _translateVerificationError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    final lower = message.toLowerCase();
    if (lower.contains('expired')) return '인증 코드가 만료됐어요. 다시 요청해 주세요.';
    if (lower.contains('invalid')) return '인증 코드가 올바르지 않아요.';
    if (lower.contains('rate') || lower.contains('too many')) {
      return '요청이 많아요. 잠시 후 다시 시도해 주세요.';
    }
    if (lower.contains('function not found')) {
      return 'Supabase Edge Function이 아직 배포되지 않았어요.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final verified = currentUser?.studentVerified == true;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 34),
                children: [
                  _StatusPanel(verified: verified),
                  const SizedBox(height: 28),
                  const Text(
                    '학교 이메일',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 9),
                  _VerificationField(
                    controller: _emailController,
                    hintText: 'example@cau.ac.kr',
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_loading && !_codeSent,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '허용 도메인: @cau.ac.kr, @m365.cau.ac.kr',
                    style: TextStyle(fontSize: 11, color: Color(0xFF909090)),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 22),
                    const Text(
                      '인증 코드',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 9),
                    _VerificationField(
                      controller: _codeController,
                      hintText: '6자리 코드',
                      keyboardType: TextInputType.number,
                      enabled: !_loading,
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 18),
                    _MessageBox(message: _message!, isError: _isError),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading
                          ? null
                          : (_codeSent ? _verifyCode : _sendCode),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFD9D9D9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _codeSent ? '인증 완료하기' : '인증 메일 보내기',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                              setState(() {
                                _codeSent = false;
                                _codeController.clear();
                                _message = null;
                              });
                            },
                      child: const Text('이메일 다시 입력하기'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 61,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDADADA))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '학생 인증',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 56),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final bool verified;

  const _StatusPanel({required this.verified});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: verified ? const Color(0xFFEAF7EE) : AppColors.primaryBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            verified ? Icons.verified_rounded : Icons.school_outlined,
            color: verified ? Colors.green : AppColors.primary,
            size: 31,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verified ? '학생 인증 완료' : '학교 이메일 인증',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  verified
                      ? '${currentUser?.schoolEmail ?? '학교 이메일'}로 인증됐어요.'
                      : '로그인 이메일과 달라도 학교 이메일로 받은 코드만 입력하면 인증돼요.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Color(0xFF777777),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final bool enabled;

  const _VerificationField({
    required this.controller,
    required this.hintText,
    required this.keyboardType,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        autocorrect: false,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hintText,
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.3),
          ),
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  final String message;
  final bool isError;

  const _MessageBox({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, height: 1.35, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
