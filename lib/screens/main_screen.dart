// lib/screens/main_screen.dart
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'create_meeting_screen.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  int _chatTabVersion = 0;
  int _profileTabVersion = 0;
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

  void _onTabTap(int index) {
    setState(() {
      _visited.add(index);
      _index = index;
      if (index == 2) _chatTabVersion++;
      if (index == 3) _profileTabVersion++;
    });
    if (index == 2 || index == 3) _startNotifications();
  }

  Widget _buildTab(int index) {
    if (!_visited.contains(index)) return const SizedBox.shrink();
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const ExploreScreen();
      case 2:
        return ChatHubScreen(key: ValueKey(_chatTabVersion));
      case 3:
        return ProfileScreen(key: ValueKey(_profileTabVersion));
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final showCreateButton = _index == 0 || _index == 1;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: List.generate(4, _buildTab),
      ),
      floatingActionButton: showCreateButton
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateMeetingScreen(),
                    fullscreenDialog: true,
                  ),
                );
                await _startNotifications();
              },
              backgroundColor: AppColors.primary,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            )
          : null,
      bottomNavigationBar: SizedBox(
        height: 60 + bottomPad,
        child: Material(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 1, color: const Color(0xFFDADADA)),
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
                      onTap: _onTabTap,
                    ),
                    _NavItem(
                      icon: Icons.explore_outlined,
                      activeIcon: Icons.explore_rounded,
                      label: '탐색',
                      index: 1,
                      current: _index,
                      onTap: _onTabTap,
                    ),
                    _NavItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      activeIcon: Icons.chat_bubble_rounded,
                      label: '채팅',
                      index: 2,
                      current: _index,
                      onTap: _onTabTap,
                    ),
                    _NavItem(
                      icon: Icons.account_circle_outlined,
                      activeIcon: Icons.account_circle_rounded,
                      label: '마이',
                      index: 3,
                      current: _index,
                      onTap: _onTabTap,
                    ),
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
              color: isActive ? AppColors.primary : const Color(0xFFA1A1A1),
              size: 26,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatHubScreen extends StatefulWidget {
  const ChatHubScreen({super.key});

  @override
  State<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends State<ChatHubScreen> {
  final _searchController = TextEditingController();
  List<MeetingModel> _meetings = [];
  bool _loading = true;
  String _query = '';

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
      final joinedMeetings = meetings.where((meeting) {
        final joined = myIds.contains(meeting.id);
        meeting.isJoined = joined;
        return joined;
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() {
        _meetings = joinedMeetings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('채팅방 목록을 불러오지 못했어요: $e')),
      );
    }
  }

  List<MeetingModel> get _filteredMeetings {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _meetings;
    return _meetings.where((meeting) {
      return meeting.title.toLowerCase().contains(query) ||
          meeting.location.toLowerCase().contains(query) ||
          meeting.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final meetings = _filteredMeetings;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          '모임 채팅방',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFDADADA)),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 361),
                  child: _SearchBox(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const _SortLabel(),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (meetings.isEmpty)
                const _EmptyChatList()
              else
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 361),
                    child: Column(
                      children: [
                        for (final meeting in meetings)
                          _ChatRoomTile(
                            meeting: meeting,
                            onOpen: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(meeting: meeting),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBox({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          hintText: '모임 채팅방 검색',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFA1A1A1)),
          suffixIcon: const Icon(
            Icons.search_rounded,
            color: Colors.black,
            size: 30,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDADADA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

class _SortLabel extends StatelessWidget {
  const _SortLabel();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '최신순',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        SizedBox(width: 1),
        Icon(Icons.keyboard_arrow_down_rounded, size: 23),
      ],
    );
  }
}

class _ChatRoomTile extends StatelessWidget {
  final MeetingModel meeting;
  final VoidCallback onOpen;

  const _ChatRoomTile({
    required this.meeting,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final isDelivery = meeting.type == MeetingType.delivery;

    return Container(
      height: 124,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFA1A1A1), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 92,
            height: 97,
            decoration: BoxDecoration(
              color: isDelivery
                  ? const Color(0xFFFFF0EF)
                  : const Color(0xFFEDEDED),
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Text(
              isDelivery ? '🛵' : '🍣',
              style: const TextStyle(fontSize: 40),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 17, bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${meeting.location.isEmpty ? '장소 미정' : meeting.location} | '
                    '${_formatKoreanDate(meeting.meetingTime)} | '
                    '${_formatKoreanTime(meeting.meetingTime)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    meeting.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 30,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 7),
                      SizedBox(
                        width: 104,
                        height: 35,
                        child: ElevatedButton(
                          onPressed: onOpen,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            '채팅방 가기',
                            style: TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatList extends StatelessWidget {
  const _EmptyChatList();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 120),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 46,
            color: AppColors.textLight,
          ),
          SizedBox(height: 14),
          Text(
            '참여 중인 모임 채팅방이 없어요.',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

String _formatKoreanDate(DateTime date) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  return '${date.month}월 ${date.day}일(${weekdays[date.weekday - 1]})';
}

String _formatKoreanTime(DateTime date) {
  final period = date.hour < 12 ? '오전' : '오후';
  final hour =
      date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
  final minute = date.minute.toString().padLeft(2, '0');
  return '$period $hour:$minute';
}
