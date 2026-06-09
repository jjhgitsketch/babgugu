// lib/screens/public_profile_screen.dart
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  UserModel? _user;
  TrustScore _trustScore = TrustScore.empty;
  bool _loading = true;
  bool _blocking = false;

  bool get _isMe => widget.userId == currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getUserById(widget.userId),
        SupabaseService.getTrustScore(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _user = results[0] as UserModel?;
        _trustScore = results[1] as TrustScore;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _blockUser() async {
    final user = _user;
    if (user == null || _isMe || _blocking) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '다시 안 만나기',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text('${user.displayName}님이 포함된 모임을 추천/탐색에서 제외할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '제외하기',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _blocking = true);
    try {
      await SupabaseService.blockUserFromRematch(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.displayName}님을 다시 안 만나기 목록에 추가했어요.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('처리하지 못했어요: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _blocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          '프로필',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFDADADA)),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : user == null
              ? const Center(
                  child: Text(
                    '프로필을 불러오지 못했어요.',
                    style:
                        TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                )
              : SafeArea(
                  top: false,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 30, 22, 34),
                    children: [
                      _PublicProfileHeader(user: user, trustScore: _trustScore),
                      const SizedBox(height: 18),
                      _InfoCard(user: user),
                      const SizedBox(height: 24),
                      _TagCard(tags: user.tags),
                      if (!_isMe) ...[
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _blocking ? null : _blockUser,
                            icon: _blocking
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.person_remove_alt_1_rounded,
                                    size: 18),
                            label: const Text('다시 안 만나기'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Color(0xFFFFB6B6)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _PublicProfileHeader extends StatelessWidget {
  final UserModel user;
  final TrustScore trustScore;

  const _PublicProfileHeader({required this.user, required this.trustScore});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ProfilePhoto(user: user, size: 82),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName.isNotEmpty ? user.displayName : '밥구구',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                '${user.gender ?? '미설정'} / ${user.age}세',
                style: const TextStyle(fontSize: 14, color: Color(0xFF555555)),
              ),
            ],
          ),
        ),
        _TrustBadge(score: trustScore),
      ],
    );
  }
}

class _ProfilePhoto extends StatelessWidget {
  final UserModel user;
  final double size;

  const _ProfilePhoto({required this.user, required this.size});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFDADADA), width: 1.3),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl == null || avatarUrl.isEmpty
          ? Icon(Icons.person_rounded, size: size * 0.58, color: Colors.black)
          : Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(Icons.person_rounded,
                  size: size * 0.58, color: Colors.black),
            ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final TrustScore score;

  const _TrustBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            score.display,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '신뢰점수',
            style: TextStyle(fontSize: 10, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final UserModel user;

  const _InfoCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final school =
        user.university?.isNotEmpty == true ? user.university! : '학교 정보 없음';
    final department =
        user.department?.isNotEmpty == true ? user.department! : '학과 미설정';
    final verified = user.studentVerified;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDADADA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '학교 정보',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.school_outlined, text: school),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.menu_book_rounded, text: department),
          const SizedBox(height: 8),
          _InfoRow(
            icon: verified
                ? Icons.verified_rounded
                : Icons.mark_email_unread_rounded,
            text: verified ? '학생 인증 완료' : '학생 인증 전',
            color: verified ? Colors.green : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _InfoRow({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color ?? AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color ?? Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}

class _TagCard extends StatelessWidget {
  final List<String> tags;

  const _TagCard({required this.tags});

  @override
  Widget build(BuildContext context) {
    final visibleTags = tags.isEmpty ? const ['대화좋아', '혼밥', '대학생'] : tags;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '태그',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 8,
          children: [
            for (final tag in visibleTags) _TagChip(label: tag),
          ],
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final text = label.startsWith('#') ? label : '#$label';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
