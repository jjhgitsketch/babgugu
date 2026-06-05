// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'meeting_detail_screen.dart';
import 'notification_screen.dart';
import 'chat_screen.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MeetingModel> _myMeetings = [];
  List<MeetingModel> _recommended = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final meetings = await SupabaseService.getMeetings();
      final matchableMeetings =
          await SupabaseService.filterMeetingsForMatching(meetings);
      final myIds = await SupabaseService.getMyMeetingIds();
      final myTags = currentUser?.tags ?? [];
      for (final m in meetings) {
        m.isJoined = myIds.contains(m.id);
        m.matchPercent = SupabaseService.calcMatch(myTags, m.tags);
      }
      setState(() {
        _myMeetings = meetings.where((m) => m.isJoined).toList();
        _recommended = matchableMeetings.where((m) => !m.isJoined).toList()
          ..sort((a, b) => b.matchPercent.compareTo(a.matchPercent));
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 상단바
            _TopBar(),
            // 탭바
            _TabBar(controller: _tabController),
            // 탭 내용
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 탭1: 나의 모임
                  _MyMeetingsTab(
                    meetings: _myMeetings,
                    loading: _loading,
                    onRefresh: _load,
                    onTap: (m) async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MeetingDetailScreen(meeting: m),
                          ));
                      _load();
                    },
                  ),
                  // 탭2: 모임 찾기
                  _FindMeetingsTab(
                    meetings: _recommended,
                    loading: _loading,
                    onRefresh: _load,
                    onTap: (m) async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MeetingDetailScreen(meeting: m),
                          ));
                      _load();
                    },
                  ),
                  // 탭3: 혼밥 추천
                  const _SoloMealTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 상단바 ───
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.primary, size: 18),
          const SizedBox(width: 4),
          Text(
            currentUser?.name != null ? '중앙대학교 다빈치캠퍼스' : '위치 설정 필요',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const Spacer(),
          ListenableBuilder(
            listenable: NotificationService.instance,
            builder: (_, __) {
              final count = NotificationService.instance.unreadCount;
              return GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationScreen())),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none_rounded,
                        color: AppColors.textPrimary, size: 26),
                    if (count > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                              color: AppColors.primary, shape: BoxShape.circle),
                          child: Center(
                            child: Text('$count',
                                style: const TextStyle(
                                    fontSize: 8,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── 탭바 ───
class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: TabBar(
        controller: controller,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        indicatorColor: AppColors.primary,
        indicatorWeight: 2.5,
        dividerColor: AppColors.divider,
        tabs: const [
          Tab(text: '나의 모임'),
          Tab(text: '모임 찾기'),
          Tab(text: '혼밥 추천'),
        ],
      ),
    );
  }
}

// ─── 탭1: 나의 모임 ───
class _MyMeetingsTab extends StatelessWidget {
  final List<MeetingModel> meetings;
  final bool loading;
  final Future<void> Function() onRefresh;
  final void Function(MeetingModel) onTap;

  const _MyMeetingsTab(
      {required this.meetings,
      required this.loading,
      required this.onRefresh,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 배고픈 메시지
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              '${currentUser?.name ?? ''}님의 현재\n참여한 모임이에요.',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.4),
            ),
          ),
          // 모임 카드 가로 스크롤
          Expanded(
            child: meetings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🍽️', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        const Text('아직 참여한 모임이 없어요',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 6),
                        const Text('모임 찾기 탭에서 모임을 찾아보세요!',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : PageView.builder(
                    padEnds: true,
                    controller: PageController(viewportFraction: 0.88),
                    itemCount: meetings.length,
                    itemBuilder: (_, i) => _MeetingBigCard(
                        meeting: meetings[i], onTap: () => onTap(meetings[i])),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── 큰 모임 카드 (Image 1 스타일) ───
class _MeetingBigCard extends StatefulWidget {
  final MeetingModel meeting;
  final VoidCallback onTap;
  const _MeetingBigCard({required this.meeting, required this.onTap});

  @override
  State<_MeetingBigCard> createState() => _MeetingBigCardState();
}

class _MeetingBigCardState extends State<_MeetingBigCard> {
  bool _leaving = false;

  Future<void> _leave() async {
    setState(() => _leaving = true);
    try {
      await SupabaseService.leaveMeeting(widget.meeting.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('모임 참여를 취소했어요'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meeting = widget.meeting;
    final daysLeft =
        meeting.meetingTime.difference(DateTime.now()).inDays.abs();

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 20),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    meeting.title,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: meeting.tags
                        .take(3)
                        .map((t) => Text('#$t ',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70)))
                        .toList(),
                  ),
                  const Spacer(),
                  // 시간
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${meeting.meetingTime.hour}:${meeting.meetingTime.minute.toString().padLeft(2, '0')} - ${meeting.meetingTime.add(const Duration(hours: 1)).hour}:${meeting.meetingTime.minute.toString().padLeft(2, '0')}',
                        style:
                            const TextStyle(fontSize: 14, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 장소
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(meeting.location,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.white),
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 인원
                  Row(
                    children: [
                      const Icon(Icons.people_outline_rounded,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(
                          '모집인원 ${meeting.currentMembers}/${meeting.maxMembers}',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white)),
                      const Spacer(),
                      // 멤버 아이콘들
                      Row(
                        children: List.generate(
                          meeting.currentMembers.clamp(0, 3),
                          (i) => Transform.translate(
                            offset: Offset(i > 0 ? -6.0 * i : 0, 0),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Icon(Icons.person,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      if (meeting.currentMembers < meeting.maxMembers)
                        Transform.translate(
                          offset: const Offset(-6, 0),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.add,
                                size: 14, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 버튼
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(meeting: meeting),
                              )),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          child: const Text('채팅방 가기',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _leaving
                              ? null
                              : () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      title: const Text('참여 취소',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800)),
                                      content: const Text('정말 모임 참여를 취소하시겠어요?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('아니요')),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('취소하기',
                                              style: TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) _leave();
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _leaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('모임 참여 취소',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // D-N 뱃지
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  daysLeft == 0 ? 'D-Day' : 'D-$daysLeft',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 탭2: 모임 찾기 ───
class _FindMeetingsTab extends StatelessWidget {
  final List<MeetingModel> meetings;
  final bool loading;
  final Future<void> Function() onRefresh;
  final void Function(MeetingModel) onTap;

  const _FindMeetingsTab(
      {required this.meetings,
      required this.loading,
      required this.onRefresh,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          // 안녕 배너
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '안녕하세요, ${currentUser?.name ?? ''}님!',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text('오늘은 누구와 함께 식사하시겠어요?',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
          // 당일 추천 모임 헤더
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Text('당일 추천 모임',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {},
                    child: const Text('전체보기 >',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
          ),
          // 모임 리스트
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _MeetingListCard(
                  meeting: meetings[i], onTap: () => onTap(meetings[i])),
              childCount: meetings.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// ─── 리스트 모임 카드 (Image 2 스타일) ───
class _MeetingListCard extends StatelessWidget {
  final MeetingModel meeting;
  final VoidCallback onTap;
  const _MeetingListCard({required this.meeting, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRestaurant = meeting.type == MeetingType.restaurant;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            // 이미지 자리
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.bgGray,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                  child: Text('🍽️', style: TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isRestaurant ? '🍽 식당' : '🛵 배달',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (meeting.matchPercent > 0) ...[
                        const Icon(Icons.auto_awesome,
                            size: 12, color: AppColors.primary),
                        const SizedBox(width: 2),
                        Text('찰떡궁합 ${meeting.matchPercent}%',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ],
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 12, color: AppColors.textLight),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(meeting.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Wrap(
                    children: meeting.tags
                        .take(3)
                        .map((t) => Text('#$t ',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)))
                        .toList(),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        '${meeting.meetingTime.hour}:${meeting.meetingTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.people_outline_rounded,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                          '모집 중 ${meeting.currentMembers}/${meeting.maxMembers}명',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 탭3: 혼밥 추천 (Image 3) ───
class _SoloMealTab extends StatelessWidget {
  const _SoloMealTab();

  // 밸런스게임 목록
  static const List<List<String>> _balanceGames = [
    ['점심 화장실에서 혼자 먹기', '점심 교수님이랑 같이 먹기'],
    ['아침 9시 1교시 수업', '저녁 6시 야간 수업'],
    ['혼밥 할인 식당 30분 대기', '배달 음식 최소 주문금액'],
  ];

  // 혼밥 장소 임시 데이터
  static const List<Map<String, String>> _soloPlaces = [
    {
      'name': '소녀식당',
      'category': '한식',
      'address': '경기 안성시 대덕면 대덕6길 21',
      'tags': '#찌개류 1인분 가능 #1인 한상차림 #생체육볶음 가성비 #사람 붐비지 않아 혼밥하기 좋음'
    },
    {
      'name': '소녀식당',
      'category': '한식',
      'address': '경기 안성시 대덕면 대덕6길 21',
      'tags': '#찌개류 1인분 가능 #1인 한상차림 #생체육볶음 가성비 #사람 붐비지 않아 혼밥하기 좋음'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final tags = currentUser?.tags ?? [];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // ─── 오늘의 메뉴 추천 ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('오늘의 메뉴 추천 🎰',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text('오늘의 추천',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: AppColors.primaryBg,
                                borderRadius: BorderRadius.circular(8)),
                            child: const Text('내 태그 기반',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: AppColors.primaryBg,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                children: [
                                  const Text('☀️',
                                      style: TextStyle(fontSize: 22)),
                                  const SizedBox(height: 4),
                                  const Text('점심',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text(tags.isNotEmpty ? tags.first : '파스타',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: AppColors.primaryBg,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                children: [
                                  const Text('🌙',
                                      style: TextStyle(fontSize: 22)),
                                  const SizedBox(height: 4),
                                  const Text('저녁',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text(tags.length > 1 ? tags[1] : '삼겹살',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── 대학생 밸런스게임 ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 130,
              child: Row(
                children: [
                  // 타이틀 박스
                  Container(
                    width: 88,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text('대학생\n밸런스게임',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.4)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 게임 카드들
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _balanceGames
                            .map((game) => Container(
                                  width: 130,
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgGray,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(game[0],
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                              height: 1.4)),
                                      const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 6),
                                        child: Text('vs',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w700)),
                                      ),
                                      Text(game[1],
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                              height: 1.4)),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── 혼밥 장소 추천 ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('혼밥 장소 추천',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: const Text('전체보기 >',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _soloPlaces.length,
              itemBuilder: (_, i) {
                final p = _soloPlaces[i];
                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Expanded(
                              child: Text(p['name']!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700))),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: AppColors.bgGray,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(p['category']!,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(p['address']!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.4)),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(p['tags']!,
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                height: 1.4),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
