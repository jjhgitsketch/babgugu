// lib/screens/meeting_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'public_profile_screen.dart';

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
    final members = memberRows.map((row) {
      final user = row['users'] as Map<String, dynamic>?;
      final userId = row['user_id'] as String? ?? '';
      final nickname = user?['nickname'] as String?;
      final name = nickname?.isNotEmpty == true
          ? nickname!
          : (user?['name'] as String?) ?? '멤버';
      return _MeetingMember(
        userId: userId,
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

  Future<void> _toggleJoin() async {
    if (_isJoined) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(meeting: widget.meeting)),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await SupabaseService.joinMeeting(widget.meeting.id);
      final myIds = await SupabaseService.getMyMeetingIds();
      await NotificationService.instance.startListening(myIds.toList());
      if (!mounted) return;
      setState(() {
        _isJoined = true;
        widget.meeting.isJoined = true;
      });
      await _loadMembers();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => const _JoinSuccessDialog(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelJoin() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await SupabaseService.leaveMeeting(widget.meeting.id);
      final myIds = await SupabaseService.getMyMeetingIds();
      await NotificationService.instance.startListening(myIds.toList());
      if (!mounted) return;
      setState(() {
        _isJoined = false;
        widget.meeting.isJoined = false;
      });
      await _loadMembers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모임 참여를 취소했어요.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('참여 취소에 실패했어요: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openBaeminTogether(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return;
    final url = trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'https://$trimmed';
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('함께주문 링크 형식이 올바르지 않아요.')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('함께주문 링크를 열지 못했어요.')),
      );
    }
  }

  Future<void> _confirmBlockUser(_MeetingMember member) async {
    if (member.userId == currentUser?.id) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '다시 안 만나기',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text('${member.name}님이 포함된 모임을 추천/탐색에서 제외할까요?'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${member.name}님을 다시 안 만나기 목록에 추가했어요.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meeting = widget.meeting;
    final isDelivery = meeting.type == MeetingType.delivery;
    final isFull = meeting.currentMembers >= meeting.maxMembers;
    final isJoinClosed = meeting.status != MeetingStatus.open;
    final details = _MeetingDetails.from(meeting);
    final baeminTogetherUrl = meeting.baeminTogetherUrl?.trim() ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _HeroSummary(
              meeting: meeting,
              isDelivery: isDelivery,
              isJoined: _isJoined,
              isFull: isFull,
              isJoinClosed: isJoinClosed,
              loading: _loading,
              onBack: () => Navigator.pop(context),
              onAction: _toggleJoin,
              onCancelJoin: _cancelJoin,
            ),
          ),
          SliverToBoxAdapter(
            child: _HostSummary(meeting: meeting),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 39, 20, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 355),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoSection(
                        title: '모임 소개',
                        child: _OutlinedBox(
                          minHeight: isDelivery ? 102 : 96,
                          child: Text(
                            details.cleanDescription.isEmpty
                                ? '아직 모임 소개가 없어요.'
                                : details.cleanDescription,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.22,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      if (isDelivery) ...[
                        const SizedBox(height: 33),
                        Row(
                          children: [
                            const Text(
                              '배달앱',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: _OutlinedBox(
                                minHeight: 40,
                                center: true,
                                child: Text(
                                  details.deliveryApp.isEmpty
                                      ? '배달앱 미정'
                                      : details.deliveryApp,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (baeminTogetherUrl.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 43,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _openBaeminTogether(baeminTogetherUrl),
                              icon: const Icon(Icons.open_in_new_rounded,
                                  size: 17),
                              label: const Text('배민 함께주문 들어가기'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 29),
                        _InfoSection(
                          title: '배달 수령지 / 소분 장소',
                          child: _OutlinedBox(
                            minHeight: 49,
                            child: Text(
                              meeting.location.isEmpty
                                  ? '장소 정보가 없어요.'
                                  : meeting.location,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 33),
                        _InfoSection(
                          title: '식당 위치',
                          child: _OutlinedBox(
                            minHeight: 49,
                            child: Text(
                              meeting.location.isEmpty
                                  ? '장소 정보가 없어요.'
                                  : meeting.location,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 33),
                      _MemberSection(
                        members: _members,
                        blockedUserIds: _blockedUserIds,
                        onBlock: _confirmBlockUser,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  final MeetingModel meeting;
  final bool isDelivery;
  final bool isJoined;
  final bool isFull;
  final bool isJoinClosed;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onAction;
  final VoidCallback onCancelJoin;

  const _HeroSummary({
    required this.meeting,
    required this.isDelivery,
    required this.isJoined,
    required this.isFull,
    required this.isJoinClosed,
    required this.loading,
    required this.onBack,
    required this.onAction,
    required this.onCancelJoin,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 444,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 372,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDelivery ? const Color(0xFFFFF0EF) : AppColors.primary,
            ),
            child: Center(
              child: Text(
                isDelivery ? '배달' : '식당',
                style: const TextStyle(fontSize: 116),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: Colors.black,
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.favorite_border_rounded),
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            top: 214,
            child: Container(
              height: 224,
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: const Color(0xFFD9D9D9)),
              ),
              child: Column(
                children: [
                  Text(
                    meeting.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_month_rounded,
                          size: 20, color: Color(0xFF4B55FF)),
                      const SizedBox(width: 5),
                      Text(
                        _formatDate(meeting.meetingTime),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 26),
                      const _FigmaPeopleIcon(),
                      const SizedBox(width: 5),
                      Text(
                        '${meeting.currentMembers}/${meeting.maxMembers}명',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _TagPreview(tags: meeting.tags),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed:
                          ((isFull || isJoinClosed) && !isJoined) || loading
                              ? null
                              : onAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: const Color(0xFFD9D9D9),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 18,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isJoined
                                  ? '채팅방 가기'
                                  : isJoinClosed
                                      ? meeting.status.label
                                      : isFull
                                          ? '모집 완료'
                                          : '모임 참여하기',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  if (isJoined) ...[
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 25,
                      child: TextButton(
                        onPressed: loading ? null : onCancelJoin,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF909090),
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '참여 취소',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPreview extends StatelessWidget {
  final List<String> tags;

  const _TagPreview({required this.tags});

  @override
  Widget build(BuildContext context) {
    final visible = tags.take(2).toList();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 9,
      runSpacing: 6,
      children: [
        for (final rawTag in visible)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              rawTag.startsWith('#') ? rawTag : '#$rawTag',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _FigmaPeopleIcon extends StatelessWidget {
  const _FigmaPeopleIcon();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF4B55FF);
    return SizedBox(
      width: 25,
      height: 25,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 3,
            top: 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 3,
            top: 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 4,
            child: Container(
              width: 12,
              height: 8,
              decoration: const BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 4,
            child: Container(
              width: 12,
              height: 8,
              decoration: const BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HostSummary extends StatelessWidget {
  final MeetingModel meeting;

  const _HostSummary({required this.meeting});

  @override
  Widget build(BuildContext context) {
    final hostName = meeting.hostName.isEmpty ? '모임장' : meeting.hostName;
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEDEDED))),
      ),
      child: Row(
        children: [
          const _AvatarCircle(size: 49, label: '밥'),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hostName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  '남 / 22세',
                  style: TextStyle(fontSize: 12, color: Colors.black),
                ),
              ],
            ),
          ),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(
                    '4.8',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.rice_bowl_rounded,
                      size: 24, color: AppColors.primary),
                ],
              ),
              Text(
                '신뢰점수',
                style: TextStyle(fontSize: 10, color: Color(0xFFD0CFCE)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 13),
        child,
      ],
    );
  }
}

class _OutlinedBox extends StatelessWidget {
  final double minHeight;
  final Widget child;
  final bool center;

  const _OutlinedBox({
    required this.minHeight,
    required this.child,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      alignment: center ? Alignment.center : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFFD9D9D9)),
      ),
      child: child,
    );
  }
}

class _MemberSection extends StatelessWidget {
  final List<_MeetingMember> members;
  final Set<String> blockedUserIds;
  final ValueChanged<_MeetingMember> onBlock;

  const _MemberSection({
    required this.members,
    required this.blockedUserIds,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '모임 멤버',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 13),
        if (members.isEmpty)
          const Text(
            '아직 표시할 멤버가 없어요.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          )
        else
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final member in members)
                _MemberChip(
                  member: member,
                  blocked: blockedUserIds.contains(member.userId),
                  onBlock: () => onBlock(member),
                ),
            ],
          ),
      ],
    );
  }
}

class _MemberChip extends StatelessWidget {
  final _MeetingMember member;
  final bool blocked;
  final VoidCallback onBlock;

  const _MemberChip({
    required this.member,
    required this.blocked,
    required this.onBlock,
  });

  void _openProfile(BuildContext context) {
    if (member.userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(userId: member.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canBlock = member.userId != currentUser?.id && !blocked;

    return SizedBox(
      width: 78,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _openProfile(context),
            child: _AvatarCircle(
              size: 64,
              label: member.name.substring(0, 1),
              avatarUrl: member.avatarUrl,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: GestureDetector(
                  onTap: () => _openProfile(context),
                  child: Text(
                    member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: blocked ? AppColors.textLight : Colors.black,
                    ),
                  ),
                ),
              ),
              if (member.userId != currentUser?.id) ...[
                const SizedBox(width: 2),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_horiz_rounded, size: 16),
                    onSelected: (_) => onBlock(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'block',
                        enabled: canBlock,
                        child: Text(blocked ? '제외됨' : '다시 안 만나기'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final double size;
  final String label;
  final String? avatarUrl;

  const _AvatarCircle({
    required this.size,
    required this.label,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EF),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD9D9D9)),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: avatarUrl == null || avatarUrl!.isEmpty
          ? Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            )
          : Image.network(
              avatarUrl!,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, __, ___) => Text(
                label,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
    );
  }
}

class _JoinSuccessDialog extends StatelessWidget {
  const _JoinSuccessDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        '모임 참여 완료',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: const Text('이제 채팅방에서 모임 멤버들과 이야기할 수 있어요.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    );
  }
}

class _MeetingDetails {
  final String cleanDescription;
  final String deliveryApp;

  const _MeetingDetails({
    required this.cleanDescription,
    required this.deliveryApp,
  });

  factory _MeetingDetails.from(MeetingModel meeting) {
    final lines = meeting.description
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    var deliveryApp = '';
    final descriptionLines = <String>[];

    for (final line in lines) {
      if (line.startsWith('배달앱:')) {
        deliveryApp = line.replaceFirst('배달앱:', '').trim();
      } else if (!line.contains('원격주문 가능') &&
          !line.contains('배달의 민족-함께주문 가능')) {
        descriptionLines.add(line);
      }
    }

    return _MeetingDetails(
      cleanDescription: descriptionLines.join('\n'),
      deliveryApp: deliveryApp,
    );
  }
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

String _formatDate(DateTime date) {
  return '${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}';
}
