// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import 'meeting_detail_screen.dart';
import 'home_screen.dart';
import 'explore_screen.dart';
import 'profile_screen.dart';
import 'create_meeting_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  final Set<int> _visited = {0};

  @override
  void initState() {
    super.initState();
    _startNotifications();
  }

  Future<void> _startNotifications() async {
    final myIds = await SupabaseService.getMyMeetingIds();
    await NotificationService.instance.startListening(myIds.toList());
  }

  @override
  void dispose() {
    NotificationService.instance.stopListening();
    super.dispose();
  }

  void _onTabTap(int i) {
    setState(() {
      _visited.add(i);
      _index = i;
    });
  }

  Widget _buildTab(int i) {
    if (!_visited.contains(i)) return const SizedBox.shrink();
    switch (i) {
      case 0:
        return const HomeScreen();
      case 1:
        return const ExploreScreen();
      case 2:
        return const MyMoimScreen();
      case 3:
        return const ProfileScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: List.generate(4, _buildTab),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateMeetingScreen(),
              fullscreenDialog: true,
            ),
          );
          _startNotifications();
        },
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: SizedBox(
        height: 60 + bottomPad,
        child: Material(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 1, color: AppColors.divider),
              SizedBox(
                height: 58,
                child: Row(
                  children: [
                    _NavItem(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_rounded,
                        label: '홈',
                        index: 0,
                        current: _index,
                        onTap: _onTabTap),
                    _NavItem(
                        icon: Icons.search_outlined,
                        activeIcon: Icons.search,
                        label: '탐색',
                        index: 1,
                        current: _index,
                        onTap: _onTabTap),
                    _NavItem(
                        icon: Icons.people_outline_rounded,
                        activeIcon: Icons.people_rounded,
                        label: 'My모임',
                        index: 2,
                        current: _index,
                        onTap: _onTabTap),
                    _NavItem(
                        icon: Icons.settings_outlined,
                        activeIcon: Icons.settings_rounded,
                        label: '설정',
                        index: 3,
                        current: _index,
                        onTap: _onTabTap),
                  ],
                ),
              ),
              SizedBox(height: bottomPad),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : AppColors.textLight,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// My모임 화면 (Image 6 - 내가 참여하는 모임)
class MyMoimScreen extends StatefulWidget {
  const MyMoimScreen({super.key});

  @override
  State<MyMoimScreen> createState() => _MyMoimScreenState();
}

class _MyMoimScreenState extends State<MyMoimScreen> {
  final _searchController = TextEditingController();
  List _meetings = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final meetings = await SupabaseService.getMeetings();
      final myIds = await SupabaseService.getMyMeetingIds();
      for (final m in meetings) {
        m.isJoined = myIds.contains(m.id);
      }
      setState(() {
        _meetings = meetings.where((m) => m.isJoined).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? _meetings
        : _meetings.where((m) => m.title.contains(_search)).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('내가 참여하는 모임'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 검색바
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.bgGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: '모임 검색',
                    hintStyle: const TextStyle(
                        color: AppColors.textLight, fontSize: 14),
                    suffixIcon: const Icon(Icons.search,
                        color: AppColors.textLight, size: 22),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
            // 정렬
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {},
                    child: Row(
                      children: [
                        const Text('최신순',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 18, color: AppColors.textPrimary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 목록
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('참여한 모임이 없어요',
                                  style: TextStyle(
                                      color: AppColors.textSecondary)))
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final m = filtered[i];
                                final isToday = DateTime.now()
                                        .difference(m.meetingTime)
                                        .inDays ==
                                    0;
                                return _MyMoimCard(
                                    meeting: m, isToday: isToday);
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyMoimCard extends StatelessWidget {
  final dynamic meeting;
  final bool isToday;
  const _MyMoimCard({required this.meeting, this.isToday = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => MeetingDetailScreen(meeting: meeting)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
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
                  Text(
                    '${meeting.location} | ${_formatDate(meeting.meetingTime)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meeting.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // 멤버 아이콘
                      const Icon(Icons.people,
                          size: 14, color: AppColors.matchHigh),
                      const SizedBox(width: 4),
                      Text(
                        '나 포함 • 총 ${meeting.currentMembers}명',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const Spacer(),
                      if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Today!',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ), // GestureDetector
    );
  }

  String _formatDate(DateTime dt) {
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${dt.month}월 ${dt.day}일(${weekdays[dt.weekday - 1]}) 오후 ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
