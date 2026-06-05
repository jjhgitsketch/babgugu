// lib/screens/meeting_detail_screen.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'chat_screen.dart';

class MeetingDetailScreen extends StatefulWidget {
  final MeetingModel meeting;
  const MeetingDetailScreen({super.key, required this.meeting});

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  late bool _isJoined;
  bool _loading = false;
  List<_MeetingMember> _members = [];
  Set<String> _blockedUserIds = {};

  @override
  void initState() {
    super.initState();
    _isJoined = widget.meeting.isJoined;
    _loadJoinStatus();
    _loadMembers();
  }

  Future<void> _loadJoinStatus() async {
    final myIds = await SupabaseService.getMyMeetingIds();
    if (!mounted) return;
    final isJoined = myIds.contains(widget.meeting.id);
    setState(() {
      _isJoined = isJoined;
      widget.meeting.isJoined = isJoined;
    });
  }

  Future<void> _loadMembers() async {
    final results = await Future.wait([
      SupabaseService.getMeetingMembers(widget.meeting.id),
      SupabaseService.getBlockedUserIds(),
    ]);
    final memberRows = results[0] as List<Map<String, dynamic>>;
    final blockedIds = results[1] as Set<String>;
    final members = memberRows.map((m) {
      final user = m['users'] as Map<String, dynamic>?;
      final uid = m['user_id'] as String? ?? '';
      final nickname = user?['nickname'] as String?;
      final name = nickname?.isNotEmpty == true
          ? nickname!
          : (user?['name'] as String?) ?? '멤버';
      return _MeetingMember(
        userId: uid,
        name: name,
        avatarUrl: user?['avatar_url'] as String?,
      );
    }).toList();
    if (!mounted) return;
    setState(() {
      _members = members;
      _blockedUserIds = blockedIds;
    });
  }

  Future<void> _confirmBlockUser(_MeetingMember member) async {
    if (member.userId == currentUser?.id) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('다시 안 만나기',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('${member.name}님이 포함된 모임은 추천과 탐색에서 제외할게요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '제외하기',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await SupabaseService.blockUserFromRematch(member.userId);
    if (!mounted) return;
    setState(() => _blockedUserIds = {..._blockedUserIds, member.userId});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${member.name}님을 재매칭 제외 목록에 추가했어요.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _toggleJoin() async {
    setState(() => _loading = true);
    try {
      if (_isJoined) {
        await SupabaseService.leaveMeeting(widget.meeting.id);
      } else {
        await SupabaseService.joinMeeting(widget.meeting.id);
      }
      final nowJoined = !_isJoined;
      setState(() {
        _isJoined = nowJoined;
        widget.meeting.isJoined = nowJoined;
      });
      final myIds = await SupabaseService.getMyMeetingIds();
      await NotificationService.instance.startListening(myIds.toList());
      if (mounted && nowJoined) {
        // 참여 완료 팝업
        await showDialog(
          context: context,
          builder: (_) => const _JoinSuccessDialog(),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('모임 참여를 취소했어요'),
          backgroundColor: AppColors.textSecondary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('오류: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meeting;
    final isDelivery = m.type == MeetingType.delivery;
    final isFull = m.currentMembers >= m.maxMembers;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ─── 상단 헤더 (코랄 배경 or 이미지) ───
          SliverAppBar(
            expandedHeight: isDelivery ? 120 : 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.bookmark_border_rounded,
                    color: Colors.white, size: 24),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.primary,
                child: isDelivery
                    ? const Center(
                        child: Text('🛵', style: TextStyle(fontSize: 56)))
                    : const Center(
                        child: Text('🍽️', style: TextStyle(fontSize: 56))),
              ),
            ),
            // appbar title (collapsed)
            title: Text(
              isDelivery ? '' : '',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── 타이틀 카드 ───
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.title,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            '${m.meetingTime.month}/${m.meetingTime.day}',
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.people_outline_rounded,
                              size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            '${m.currentMembers}/${m.maxMembers}명',
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: m.tags
                            .map((t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBg,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('#$t',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600)),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      // 참여 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (isFull && !_isJoined) || _loading
                              ? null
                              : _toggleJoin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _isJoined ? Colors.white : AppColors.primary,
                            foregroundColor:
                                _isJoined ? AppColors.primary : Colors.white,
                            side: _isJoined
                                ? const BorderSide(color: AppColors.primary)
                                : null,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                            elevation: 0,
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Text(
                                  _isJoined
                                      ? '참여 취소'
                                      : isFull
                                          ? '모집 완료'
                                          : '모임 참여하기',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── 모임 소개 ───
                _Section(
                  title: '모임 소개',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bgGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          m.description.isEmpty ? '모임 소개글' : m.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: m.description.isEmpty
                                ? AppColors.textLight
                                : AppColors.textPrimary,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (m.description.isEmpty)
                          const Text('-모임 목적',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textLight)),
                      ],
                    ),
                  ),
                ),

                // ─── 배달앱 (배달 모임만) ───
                if (isDelivery)
                  _Section(
                    title: '배달앱',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.bgGray,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '배민 or 요기요\nor 쿠팡이츠...',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5),
                      ),
                    ),
                  ),

                // ─── 위치 ───
                _Section(
                  title: isDelivery ? '배달 수령지 / 소분 장소' : '위치',
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: isDelivery
                        ? Text(
                            m.location.isEmpty
                                ? '중앙대학교 다빈치 캠퍼스 후문 앞'
                                : m.location,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                          )
                        : Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppColors.bgGray,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                    child: Text('📍',
                                        style: TextStyle(fontSize: 24))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.location.isEmpty
                                          ? '식당 이름 / 어디 지점'
                                          : m.location,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text('영업중',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green,
                                            fontWeight: FontWeight.w600)),
                                    if (m.address != null)
                                      Text(m.address!,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                // ─── 지도 미리보기 (식당 + 위치 있을 때) ───
                if (!isDelivery && m.hasLocation)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 160,
                        child: _NaverMapPreview(
                            latitude: m.latitude!,
                            longitude: m.longitude!,
                            label: m.location),
                      ),
                    ),
                  ),

                // ─── 모임 멤버 ───
                _Section(
                  title: '모임 멤버',
                  child: Row(
                    children: List.generate(
                      m.currentMembers.clamp(0, 5),
                      (i) {
                        final colors = [
                          AppColors.primary,
                          const Color(0xFFFFB347),
                          const Color(0xFF888888),
                          AppColors.primaryLight,
                          const Color(0xFFA0C4FF)
                        ];
                        return Container(
                          width: 48,
                          height: 48,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: colors[i % colors.length],
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                              child: Icon(Icons.person_rounded,
                                  color: Colors.white, size: 24)),
                        );
                      },
                    ),
                  ),
                ),

                // ─── 채팅방 (참여자만) ───
                if (_members.isNotEmpty)
                  _Section(
                    title: '재매칭 제외',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 12,
                      children: _members.map((member) {
                        final isMe = member.userId == currentUser?.id;
                        final isBlocked =
                            _blockedUserIds.contains(member.userId);
                        return _MemberChip(
                          member: member,
                          isMe: isMe,
                          isBlocked: isBlocked,
                          onBlock: isMe || isBlocked
                              ? null
                              : () => _confirmBlockUser(member),
                        );
                      }).toList(),
                    ),
                  ),

                if (_isJoined)
                  _Section(
                    title: '채팅방',
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ChatScreen(meeting: m))),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                color: AppColors.primary, size: 22),
                            SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('실시간 채팅방',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                  Text('입장하기',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                ])),
                            Icon(Icons.chevron_right,
                                color: AppColors.textLight),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}

class _MeetingMember {
  final String userId;
  final String name;
  final String? avatarUrl;

  const _MeetingMember({
    required this.userId,
    required this.name,
    this.avatarUrl,
  });
}

class _MemberChip extends StatelessWidget {
  final _MeetingMember member;
  final bool isMe;
  final bool isBlocked;
  final VoidCallback? onBlock;

  const _MemberChip({
    required this.member,
    required this.isMe,
    required this.isBlocked,
    this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isBlocked ? AppColors.bgGray : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBlocked ? AppColors.textLight : AppColors.divider,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: member.avatarUrl == null
                ? null
                : NetworkImage(member.avatarUrl!),
            child: member.avatarUrl == null
                ? const Icon(Icons.person_rounded,
                    color: Colors.white, size: 24)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            isMe ? '나' : member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          if (isBlocked)
            const Text(
              '제외됨',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            )
          else if (!isMe)
            GestureDetector(
              onTap: onBlock,
              child: const Text(
                '다시 안 만나기',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            )
          else
            const SizedBox(height: 13),
        ],
      ),
    );
  }
}

// 네이버 지도 미리보기
class _NaverMapPreview extends StatelessWidget {
  final double latitude, longitude;
  final String label;
  const _NaverMapPreview(
      {required this.latitude, required this.longitude, required this.label});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.tagBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined,
                  color: AppColors.primary, size: 32),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
              const SizedBox(height: 4),
              Text(
                '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    return _NaverMapWidget(
        latitude: latitude, longitude: longitude, label: label);
  }
}

// 모바일 전용 네이버 지도
class _NaverMapWidget extends StatefulWidget {
  final double latitude, longitude;
  final String label;
  const _NaverMapWidget(
      {required this.latitude, required this.longitude, required this.label});

  @override
  State<_NaverMapWidget> createState() => _NaverMapWidgetState();
}

class _NaverMapWidgetState extends State<_NaverMapWidget> {
  @override
  Widget build(BuildContext context) {
    // 모바일에서만 네이버 지도 사용
    return Container(
      decoration: BoxDecoration(
        color: AppColors.tagBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.place, color: AppColors.primary, size: 32),
            const SizedBox(height: 8),
            Text(widget.label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

// ─── 참여 완료 팝업 (Image 2) ───
class _JoinSuccessDialog extends StatelessWidget {
  const _JoinSuccessDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.bgGray,
                shape: BoxShape.circle,
              ),
              child: const Center(
                  child: Text('🎉', style: TextStyle(fontSize: 40))),
            ),
            const SizedBox(height: 20),
            const Text('모임 참여 완료!',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('채팅방으로\n이동할까요?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBg,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Center(
                        child: Text('아니요',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text('이동하기',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
