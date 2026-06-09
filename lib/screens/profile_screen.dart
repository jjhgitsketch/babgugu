// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'auth/login_screen.dart';
import 'edit_profile_screen.dart';
import 'meeting_detail_screen.dart';
import 'student_verification_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<MeetingModel> _createdMeetings = [];
  TrustScore _trustScore = TrustScore.empty;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      final results = await Future.wait([
        SupabaseService.getMeetings(),
        SupabaseService.getTrustScore(user.id),
        SupabaseService.getMyMeetingIds(),
      ]);
      final meetings = results[0] as List<MeetingModel>;
      final trustScore = results[1] as TrustScore;
      final myIds = results[2] as Set<String>;

      if (!mounted) return;
      setState(() {
        _createdMeetings = meetings.where((meeting) {
          final joined = myIds.contains(meeting.id);
          meeting.isJoined = joined;
          return meeting.hostId == user.id && joined;
        }).toList();
        _trustScore = trustScore;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goEditProfile() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (changed == true) _load();
  }

  Future<void> _goStudentVerification() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const StudentVerificationScreen()),
    );
    if (changed == true) _load();
  }

  Future<void> _goTagEdit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TagEditScreen()),
    );
    if (changed == true) _load();
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '로그아웃',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text('정말 로그아웃 하시겠어요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '로그아웃',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await SupabaseService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 34, 20, 110),
            children: [
              Row(
                children: [
                  const Text(
                    '내 프로필',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    tooltip: '로그아웃',
                  ),
                ],
              ),
              const SizedBox(height: 30),
              _ProfileHeader(user: user, trustScore: _trustScore),
              if (_hasSchoolInfo(user)) ...[
                const SizedBox(height: 14),
                _SchoolInfoCard(user: user),
              ],
              const SizedBox(height: 12),
              _StudentVerificationCard(
                user: user,
                onTap: _goStudentVerification,
              ),
              const SizedBox(height: 13),
              SizedBox(
                height: 45,
                child: OutlinedButton.icon(
                  onPressed: _goEditProfile,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('프로필 편집'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Color(0xFFDADADA)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              _TagSection(tags: user?.tags ?? const [], onEdit: _goTagEdit),
              const SizedBox(height: 30),
              const Text(
                '오늘의 메뉴 추천 🎲',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 19),
              const _MenuRecommendCard(),
              if (_createdMeetings.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Text(
                  '내가 생성한 모임',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                ..._createdMeetings.take(3).map(
                      (meeting) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CreatedMeetingCard(
                          meeting: meeting,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MeetingDetailScreen(meeting: meeting),
                              ),
                            );
                            _load();
                          },
                        ),
                      ),
                    ),
              ],
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 26),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasSchoolInfo(UserModel? user) {
    return (user?.university?.isNotEmpty == true) ||
        (user?.department?.isNotEmpty == true) ||
        (user?.studentId?.isNotEmpty == true);
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel? user;
  final TrustScore trustScore;

  const _ProfileHeader({required this.user, required this.trustScore});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ProfileAvatar(user: user, size: 75),
        const SizedBox(width: 17),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.displayName.isNotEmpty == true
                    ? user!.displayName
                    : '밥구구',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                '${user?.gender ?? '남'} / ${user?.age ?? 22}세',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        _TrustScoreBadge(score: trustScore),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final UserModel? user;
  final double size;

  const _ProfileAvatar({required this.user, required this.size});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user?.avatarUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD9D9D9), width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl == null
          ? Icon(Icons.person_rounded, size: size * 0.58, color: Colors.black)
          : Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.person_rounded,
                size: size * 0.58,
                color: Colors.black,
              ),
            ),
    );
  }
}

class _TrustScoreBadge extends StatelessWidget {
  final TrustScore score;

  const _TrustScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                score.display,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.rice_bowl_rounded,
                  size: 21, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            '신뢰점수',
            style: TextStyle(fontSize: 10, color: Color(0xFFD0CFCE)),
          ),
        ],
      ),
    );
  }
}

class _SchoolInfoCard extends StatelessWidget {
  final UserModel? user;

  const _SchoolInfoCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final university =
        user?.university?.isNotEmpty == true ? user!.university! : '학교 정보 없음';
    final detail = [
      if (user?.department?.isNotEmpty == true) user!.department!,
      if (user?.studentId?.isNotEmpty == true) user!.studentId!,
    ].join(' ・ ');

    return Container(
      height: 57,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDADADA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_outlined, size: 24, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  university,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7C7C7C),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentVerificationCard extends StatelessWidget {
  final UserModel? user;
  final VoidCallback onTap;

  const _StudentVerificationCard({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final verified = user?.studentVerified == true;
    final email = user?.schoolEmail;

    return InkWell(
      onTap: verified ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: verified ? const Color(0xFFEAF7EE) : AppColors.primaryBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: verified
                ? const Color(0xFFBDE5C8)
                : AppColors.primary.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                verified ? Icons.verified_rounded : Icons.mark_email_unread,
                size: 20,
                color: verified ? Colors.green : AppColors.primary,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    verified ? '학생 인증 완료' : '학교 이메일로 학생 인증하기',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    verified
                        ? (email?.isNotEmpty == true
                            ? email!
                            : '학교 이메일 인증이 완료됐어요')
                        : '@cau.ac.kr 이메일로 인증 코드를 받아요',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF777777),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              verified
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              color: verified ? Colors.green : AppColors.primary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _TagSection extends StatelessWidget {
  final List<String> tags;
  final VoidCallback onEdit;

  const _TagSection({required this.tags, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '내 태그',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onEdit,
              child: const Row(
                children: [
                  Icon(Icons.edit, size: 18, color: AppColors.primary),
                  SizedBox(width: 2),
                  Text(
                    '태그 편집',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        const Text(
          '이 태그를 기반으로 모임이 추천돼요',
          style: TextStyle(fontSize: 14, color: Color(0xFF7C7C7C)),
        ),
        const SizedBox(height: 13),
        Wrap(
          spacing: 5,
          runSpacing: 6,
          children: (tags.isEmpty ? const ['#여행', '#사진', '#음악'] : tags)
              .map((tag) => _ProfileTagChip(label: tag))
              .toList(),
        ),
      ],
    );
  }
}

class _ProfileTagChip extends StatelessWidget {
  final String label;

  const _ProfileTagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final text = label.startsWith('#') ? label : '#$label';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _MenuRecommendCard extends StatelessWidget {
  const _MenuRecommendCard();

  @override
  Widget build(BuildContext context) {
    final tags = currentUser?.tags ?? [];
    final lunch = _pickMenu(tags, const ['부리또', '김치찌개', '초밥', '파스타'], 0);
    final dinner = _pickMenu(tags, const ['치즈 돈까스', '마라탕', '치킨', '라멘'], 7);

    return Container(
      height: 168,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDADADA), width: 1.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EF),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.primary, width: 0.7),
            ),
            child: const Text(
              '내 태그 기반',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child:
                      _MealTile(label: '점심', menu: lunch, icon: Icons.wb_sunny),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MealTile(
                      label: '저녁', menu: dinner, icon: Icons.nightlight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _pickMenu(
      List<String> tags, List<String> fallback, int offset) {
    final seed = DateTime.now().year * 10000 +
        DateTime.now().month * 100 +
        DateTime.now().day +
        tags.length +
        offset;
    return fallback[seed % fallback.length];
  }
}

class _MealTile extends StatelessWidget {
  final String label;
  final String menu;
  final IconData icon;

  const _MealTile({
    required this.label,
    required this.menu,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      constraints: const BoxConstraints(minHeight: 92),
      decoration: BoxDecoration(
        color: const Color(0xFFFFCCC9).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF7C7C7C)),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            menu,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatedMeetingCard extends StatelessWidget {
  final MeetingModel meeting;
  final VoidCallback onTap;

  const _CreatedMeetingCard({required this.meeting, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 116,
        child: Row(
          children: [
            Container(
              width: 105,
              decoration: const BoxDecoration(
                color: Color(0xFFD9D9D9),
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(13)),
              ),
              child:
                  const Icon(Icons.restaurant, color: Colors.white, size: 36),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD9D9D9)),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(13),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Center(
                            child: Text(
                              meeting.type == MeetingType.delivery
                                  ? '배달'
                                  : '식당',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Icon(Icons.auto_awesome, size: 14),
                        Text(
                          '찰떡궁합 ${meeting.matchPercent}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      meeting.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meeting.tags.take(3).join(' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF909090)),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16),
                        Expanded(
                          child: Text(
                            meeting.location.isEmpty
                                ? '장소 미정'
                                : meeting.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.person_outline, size: 16),
                        Text(
                          '${meeting.currentMembers} / ${meeting.maxMembers} 명',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
