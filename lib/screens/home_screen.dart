// lib/screens/home_screen.dart
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'explore_screen.dart';
import 'meeting_detail_screen.dart';
import 'notification_screen.dart';
import 'saved_meetings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MeetingModel> _myMeetings = [];
  List<MeetingModel> _recommended = [];
  Set<String> _savedMeetingIds = {};
  bool _loading = true;
  int _selectedTab = 0;
  int _myMeetingPage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final meetings = await SupabaseService.getMeetingsExcludingBlocked();
      final myIds = await SupabaseService.getMyMeetingIds();
      final savedIds = await SupabaseService.getSavedMeetingIds();
      final myTags = currentUser?.tags ?? [];
      await NotificationService.instance.startListening(myIds.toList());

      for (final meeting in meetings) {
        meeting.isJoined = myIds.contains(meeting.id);
        meeting.matchPercent = SupabaseService.calcMatch(myTags, meeting.tags);
      }

      final recommended = meetings.where((m) => !m.isJoined).toList()
        ..sort((a, b) => b.matchPercent.compareTo(a.matchPercent));

      if (!mounted) return;
      setState(() {
        _myMeetings = meetings.where((m) => m.isJoined).toList();
        _recommended = recommended;
        _savedMeetingIds = savedIds;
        _loading = false;
        if (_myMeetingPage >= _myMeetings.length) _myMeetingPage = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('모임을 불러오지 못했어요: $e')),
      );
    }
  }

  Future<void> _openMeeting(MeetingModel meeting) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MeetingDetailScreen(meeting: meeting)),
    );
    _load();
  }

  void _openChat(MeetingModel meeting) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(meeting: meeting)),
    );
  }

  Future<void> _leaveMeeting(MeetingModel meeting) async {
    try {
      await SupabaseService.leaveMeeting(meeting.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모임 참여를 취소했어요.')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('참여 취소에 실패했어요: $e')),
      );
    }
  }

  Future<void> _toggleSave(MeetingModel meeting) async {
    final wasSaved = _savedMeetingIds.contains(meeting.id);
    setState(() {
      if (wasSaved) {
        _savedMeetingIds.remove(meeting.id);
      } else {
        _savedMeetingIds.add(meeting.id);
      }
    });

    try {
      if (wasSaved) {
        await SupabaseService.unsaveMeeting(meeting.id);
      } else {
        await SupabaseService.saveMeeting(meeting.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasSaved) {
          _savedMeetingIds.add(meeting.id);
        } else {
          _savedMeetingIds.remove(meeting.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 상태를 바꾸지 못했어요: $e')),
      );
    }
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationScreen()),
    );
  }

  void _openSavedMeetings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SavedMeetingsScreen()),
    ).then((_) => _load());
  }

  void _openSoloPlaces() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SoloPlaceListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _HomeHeader(
              selectedTab: _selectedTab,
              onTabChanged: (index) => setState(() => _selectedTab = index),
              onSavedTap: _openSavedMeetings,
              onNotificationTap: _openNotifications,
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else
              switch (_selectedTab) {
                0 => _MyMeetingsPanel(
                    meetings: _myMeetings,
                    page: _myMeetingPage,
                    onPageChanged: (page) =>
                        setState(() => _myMeetingPage = page),
                    onChatTap: _openChat,
                    onCancelTap: _leaveMeeting,
                  ),
                1 => _RecommendedMeetingsPanel(
                    meetings: _recommended,
                    savedMeetingIds: _savedMeetingIds,
                    onMeetingTap: _openMeeting,
                    onSaveTap: _toggleSave,
                    onSeeAll: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExploreScreen()),
                    ),
                  ),
                _ => _SoloRecommendationPanel(onSeeAll: _openSoloPlaces),
              },
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onSavedTap;
  final VoidCallback onNotificationTap;

  const _HomeHeader({
    required this.selectedTab,
    required this.onTabChanged,
    required this.onSavedTap,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = currentUser?.displayName.isNotEmpty == true
        ? currentUser!.displayName
        : '\uBC25\uAD6C\uAD6C';
    final isMyTab = selectedTab == 0;
    final headerColor = isMyTab ? Colors.white : AppColors.primary;
    final foreground = isMyTab ? Colors.black : Colors.white;
    final locationColor = isMyTab ? AppColors.primary : Colors.black;

    return Container(
      height: isMyTab ? 250 : 220,
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(5)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, size: 21, color: locationColor),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      '\uC911\uC559\uB300\uD559\uAD50 \uB2E4\uBE48\uCE58\uCEA0\uD37C\uC2A4',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: locationColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: onSavedTap,
                    icon: const Icon(Icons.favorite_border_rounded),
                    color: foreground,
                    tooltip: '\uC800\uC7A5\uD55C \uBAA8\uC784',
                  ),
                  IconButton(
                    onPressed: onNotificationTap,
                    icon: AnimatedBuilder(
                      animation: NotificationService.instance,
                      builder: (context, _) {
                        final unread = NotificationService.instance.unreadCount;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_rounded),
                            if (unread > 0)
                              Positioned(
                                right: -1,
                                top: -2,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isMyTab
                                        ? AppColors.primary
                                        : Colors.black,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    color: foreground,
                    tooltip: '\uC54C\uB9BC',
                  ),
                ],
              ),
              SizedBox(height: isMyTab ? 26 : 18),
              if (isMyTab) ...[
                Text(
                  '\uBC25\uAD6C\uAD6C $displayName\uB2D8\uC758',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '\uD604\uC7AC \uCC38\uC5EC\uD55C \uBAA8\uC784\uC5D0\uC11C',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ] else ...[
                Text(
                  '\uC548\uB155\uD558\uC138\uC694, \uBC25\uAD6C\uAD6C $displayName\uB2D8',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  selectedTab == 2
                      ? '\uC624\uB298 \uD63C\uBC25\uD558\uAE30 \uC88B\uC740 \uBA54\uB274\uC640 \uC7A5\uC18C\uB97C \uACE8\uB77C\uBD10\uC694'
                      : '\uC624\uB298\uC740 \uB204\uAD6C\uC640 \uD568\uAED8 \uC2DD\uC0AC\uD558\uC2DC\uACA0\uC5B4\uC694?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                ),
              ],
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _HeaderTab(
                    label: '\uB098\uC758 \uBAA8\uC784',
                    selected: selectedTab == 0,
                    selectedColor: isMyTab ? Colors.black : Colors.white,
                    baseColor: isMyTab ? Colors.black54 : Colors.white70,
                    onTap: () => onTabChanged(0),
                  ),
                  _HeaderTab(
                    label: '\uBAA8\uC784 \uCC3E\uAE30',
                    selected: selectedTab == 1,
                    selectedColor: isMyTab ? Colors.black : Colors.white,
                    baseColor: isMyTab ? Colors.black54 : Colors.white70,
                    onTap: () => onTabChanged(1),
                  ),
                  _HeaderTab(
                    label: '\uD63C\uBC25 \uCD94\uCC9C',
                    selected: selectedTab == 2,
                    selectedColor: isMyTab ? Colors.black : Colors.white,
                    baseColor: isMyTab ? Colors.black54 : Colors.white70,
                    onTap: () => onTabChanged(2),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color baseColor;
  final VoidCallback onTap;

  const _HeaderTab({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.baseColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
        decoration: BoxDecoration(
          border: selected
              ? Border(bottom: BorderSide(color: selectedColor, width: 2))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? selectedColor : baseColor,
          ),
        ),
      ),
    );
  }
}

class _MyMeetingsPanel extends StatelessWidget {
  final List<MeetingModel> meetings;
  final int page;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<MeetingModel> onChatTap;
  final ValueChanged<MeetingModel> onCancelTap;

  const _MyMeetingsPanel({
    required this.meetings,
    required this.page,
    required this.onPageChanged,
    required this.onChatTap,
    required this.onCancelTap,
  });

  @override
  Widget build(BuildContext context) {
    if (meetings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 32, 20, 0),
        child: _EmptyState(
          title:
              '\uCC38\uC5EC \uC911\uC778 \uBAA8\uC784\uC774 \uC544\uC9C1 \uC5C6\uC5B4\uC694',
          message:
              '\uC0C8 \uBAA8\uC784\uC744 \uB9CC\uB4E4\uAC70\uB098 \uD0D0\uC0C9\uC5D0\uC11C \uCC3E\uC544\uBCF4\uC138\uC694.',
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 21),
        SizedBox(
          height: 430,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.86),
            itemCount: meetings.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final meeting = meetings[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _MyMeetingCard(
                  meeting: meeting,
                  onChatTap: () => onChatTap(meeting),
                  onCancelTap: () => onCancelTap(meeting),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            meetings.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: page == index ? 15 : 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color:
                    page == index ? AppColors.primary : const Color(0xFFD9D9D9),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MyMeetingCard extends StatelessWidget {
  final MeetingModel meeting;
  final VoidCallback onChatTap;
  final VoidCallback onCancelTap;

  const _MyMeetingCard({
    required this.meeting,
    required this.onChatTap,
    required this.onCancelTap,
  });

  @override
  Widget build(BuildContext context) {
    final tags = meeting.tags.take(3).join(' ');
    final date = _formatDate(meeting.meetingTime);
    final dDay = _dDayText(meeting.meetingTime);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 23, 22, 20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  meeting.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 25,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  dDay,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tags.isEmpty
                ? '#\uBC25\uAD6C\uAD6C #\uC2DD\uC0AC\uBAA8\uC784'
                : tags,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          _MeetingInfoLine(icon: Icons.calendar_today_outlined, text: date),
          const SizedBox(height: 13),
          _MeetingInfoLine(
            icon: Icons.location_on_outlined,
            text: meeting.location.isEmpty
                ? '\uC7A5\uC18C \uBBF8\uC815'
                : meeting.location,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const _MiniAvatar(index: 0),
              const SizedBox(width: 4),
              const _MiniAvatar(index: 1),
              const SizedBox(width: 4),
              const _MiniAvatar(index: 2),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '\uBAA8\uC9D1\uC778\uC6D0 ${meeting.currentMembers}/${meeting.maxMembers}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 49,
                  child: ElevatedButton(
                    onPressed: onChatTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text('\uCC44\uD305\uBC29 \uAC00\uAE30'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 49,
                  child: OutlinedButton(
                    onPressed: onCancelTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      '\uBAA8\uC784 \uCC38\uC5EC \uCDE8\uC18C',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeetingInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MeetingInfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final int index;

  const _MiniAvatar({required this.index});

  static const _colors = [
    Color(0xFFFFFFFF),
    Color(0xFFFFD9D9),
    Color(0xFFFFB9B9),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: _colors[index % _colors.length],
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(
        Icons.person_rounded,
        size: 17,
        color: index == 0 ? AppColors.primary : Colors.white,
      ),
    );
  }
}

class _RecommendedMeetingsPanel extends StatelessWidget {
  final List<MeetingModel> meetings;
  final Set<String> savedMeetingIds;
  final ValueChanged<MeetingModel> onMeetingTap;
  final ValueChanged<MeetingModel> onSaveTap;
  final VoidCallback onSeeAll;

  const _RecommendedMeetingsPanel({
    required this.meetings,
    required this.savedMeetingIds,
    required this.onMeetingTap,
    required this.onSaveTap,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (meetings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 32, 20, 0),
        child: _EmptyState(
          title:
              '\uCD94\uCC9C\uD560 \uBAA8\uC784\uC774 \uC544\uC9C1 \uC5C6\uC5B4\uC694.',
          message:
              '\uC0C8 \uBAA8\uC784\uC774 \uC0DD\uAE30\uBA74 \uC5EC\uAE30\uC5D0\uC11C \uBCF4\uC5EC\uB4DC\uB9B4\uAC8C\uC694.',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '\uB9DE\uCDA4 \uBAA8\uC784 \uCD94\uCC9C',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              TextButton(
                onPressed: onSeeAll,
                child: const Text('\uC804\uCCB4\uBCF4\uAE30>'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...meetings.take(5).map(
                (meeting) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _MeetingListCard(
                    meeting: meeting,
                    saved: savedMeetingIds.contains(meeting.id),
                    onTap: () => onMeetingTap(meeting),
                    onSaveTap: () => onSaveTap(meeting),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _MeetingListCard extends StatelessWidget {
  final MeetingModel meeting;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onSaveTap;

  const _MeetingListCard({
    required this.meeting,
    required this.saved,
    required this.onTap,
    required this.onSaveTap,
  });

  @override
  Widget build(BuildContext context) {
    final typeLabel = meeting.type == MeetingType.restaurant
        ? '\uC2DD\uB2F9'
        : '\uBC30\uB2EC';
    final typeIcon = meeting.type == MeetingType.restaurant
        ? Icons.restaurant_rounded
        : Icons.delivery_dining_rounded;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 138,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E2E2)),
        ),
        child: Row(
          children: [
            Container(
              width: 104,
              height: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEEEE),
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(14)),
              ),
              child: Icon(typeIcon, size: 42, color: AppColors.primary),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            typeLabel,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '\uCC30\uB5A1\uAD81\uD569 ${meeting.matchPercent}%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onSaveTap,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 28,
                          ),
                          icon: Icon(
                            saved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meeting.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meeting.tags.take(3).join(' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF909090),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            meeting.location.isEmpty
                                ? '\uC704\uCE58 \uBBF8\uC815'
                                : meeting.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10.5),
                          ),
                        ),
                        Text(
                          '${meeting.currentMembers}/${meeting.maxMembers}\uBA85',
                          style: const TextStyle(fontSize: 10.5),
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

class _SoloRecommendationPanel extends StatelessWidget {
  final VoidCallback onSeeAll;

  const _SoloRecommendationPanel({required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '\uC624\uB298\uC758 \uBA54\uB274 \uCD94\uCC9C',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 13),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Container(
              height: 154,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBg,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      '\uB0B4 \uD0DC\uADF8 \uAE30\uBC18',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  const Row(
                    children: [
                      Expanded(
                        child: _MenuRecommendCard(
                          label: '\uC810\uC2EC',
                          menu: '\uBD80\uB9AC\uB610',
                          icon: Icons.lunch_dining_rounded,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _MenuRecommendCard(
                          label: '\uC800\uB141',
                          menu: '\uCE58\uC988 \uB3C8\uAE4C\uC2A4',
                          icon: Icons.dinner_dining_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              children: [
                const Icon(Icons.location_on,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    '\uD63C\uBC25 \uC7A5\uC18C \uCD94\uCC9C',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onSeeAll,
                  child: const Text(
                    '\uC804\uCCB4\uBCF4\uAE30>',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFAAAAAA),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 182,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 20),
              itemCount: _soloPlaces.take(5).length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _SoloPlaceCard(place: _soloPlaces[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRecommendCard extends StatelessWidget {
  final String label;
  final String menu;
  final IconData icon;

  const _MenuRecommendCard({
    required this.label,
    required this.menu,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 25, color: AppColors.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  menu,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
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

class _SoloPlaceCard extends StatelessWidget {
  final SoloPlace place;

  const _SoloPlaceCard({required this.place});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE3E3E3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 76,
            color: place.color.withValues(alpha: 0.16),
            child: Center(
              child: Icon(place.icon, size: 40, color: place.color),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 8, 11, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  place.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF909090),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.directions_walk_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 3),
                    Text(
                      place.distance,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 20,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: place.tags.take(2).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 4),
                    itemBuilder: (context, index) {
                      return _MiniChip(label: place.tags[index]);
                    },
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

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class SoloPlaceListScreen extends StatefulWidget {
  const SoloPlaceListScreen({super.key});

  @override
  State<SoloPlaceListScreen> createState() => _SoloPlaceListScreenState();
}

class _SoloPlaceListScreenState extends State<SoloPlaceListScreen> {
  bool _showCategories = false;
  String _selectedCategory = '전체';
  String _searchQuery = '';

  List<SoloPlace> get _visiblePlaces {
    final query = _searchQuery.trim().toLowerCase();
    return _soloPlaces
        .where((place) =>
            _selectedCategory == '전체' || place.group == _selectedCategory)
        .where((place) {
      if (query.isEmpty) return true;
      return place.name.toLowerCase().contains(query) ||
          place.category.toLowerCase().contains(query) ||
          place.address.toLowerCase().contains(query) ||
          place.menu.toLowerCase().contains(query) ||
          place.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 19, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        tooltip: '뒤로가기',
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SoloSearchField(
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                SizedBox(
                  height: 47,
                  child: Row(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _foodCategories.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 28),
                          itemBuilder: (context, index) {
                            final category = _foodCategories[index];
                            final selected = category == _selectedCategory;
                            return GestureDetector(
                              onTap: () => setState(
                                () => _selectedCategory = category,
                              ),
                              child: Center(
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                    color: selected
                                        ? AppColors.primary
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: GestureDetector(
                          onTap: () => setState(
                            () => _showCategories = !_showCategories,
                          ),
                          child: Container(
                            width: 23,
                            height: 23,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _showCategories
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFBDBDBD)),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 36, 20, 96),
                    itemCount: _visiblePlaces.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 15, color: Color(0xFFBDBDBD)),
                    itemBuilder: (context, index) {
                      return _SoloPlaceListTile(place: _visiblePlaces[index]);
                    },
                  ),
                ),
              ],
            ),
            if (_showCategories) ...[
              Positioned.fill(
                top: 170,
                child: GestureDetector(
                  onTap: () => setState(() => _showCategories = false),
                  child: Container(color: Colors.black.withValues(alpha: 0.7)),
                ),
              ),
              Positioned(
                top: 122,
                left: 0,
                right: 0,
                child: _CategoryPanel(
                  selectedCategory: _selectedCategory,
                  onClose: () => setState(() => _showCategories = false),
                  onSelect: (category) => setState(() {
                    _selectedCategory = category;
                    _showCategories = false;
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SoloSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SoloSearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.only(left: 15, right: 8),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: '혼밥 장소 검색',
          hintStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFFAAAAAA),
          ),
          suffixIcon: Icon(
            Icons.search_rounded,
            size: 28,
            color: Color(0xFFAAAAAA),
          ),
          suffixIconConstraints: BoxConstraints(minWidth: 34, minHeight: 34),
        ),
      ),
    );
  }
}

class _SoloPlaceListTile extends StatelessWidget {
  final SoloPlace place;

  const _SoloPlaceListTile({required this.place});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: Row(
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              color: place.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(place.icon, size: 48, color: place.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      place.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF909090),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded,
                        size: 32, color: Colors.black),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  place.tags.map((tag) => '#$tag').join(' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF909090),
                  ),
                ),
                const SizedBox(height: 5),
                _PlaceMetaLine(
                  icon: Icons.location_on_outlined,
                  text: place.address,
                ),
                const SizedBox(height: 1),
                _PlaceMetaLine(
                  icon: Icons.schedule_rounded,
                  text: '영업 중 ? ${place.hours}',
                ),
                const SizedBox(height: 1),
                _PlaceMetaLine(
                  icon: Icons.thumb_up_alt_outlined,
                  text: place.menu,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceMetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PlaceMetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.black),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.black),
          ),
        ),
      ],
    );
  }
}

class _CategoryPanel extends StatelessWidget {
  final String selectedCategory;
  final VoidCallback onClose;
  final ValueChanged<String> onSelect;

  const _CategoryPanel({
    required this.selectedCategory,
    required this.onClose,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final categories =
        _foodCategories.where((category) => category != '\uC804\uCCB4');

    return Container(
      height: 399,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '\uBA54\uB274 \uC804\uCCB4 \uBCF4\uAE30',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
                tooltip: '\uB2EB\uAE30',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 20,
                crossAxisSpacing: 14,
                mainAxisExtent: 92,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories.elementAt(index);
                final selected = selectedCategory == category;
                return GestureDetector(
                  onTap: () => onSelect(category),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x16000000),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          _categoryIcon(category),
                          color: selected ? Colors.white : AppColors.primary,
                          size: 29,
                        ),
                      ),
                      const SizedBox(height: 9),
                      SizedBox(
                        width: 58,
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;

  const _MiniChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primaryBg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class SoloPlace {
  final String name;
  final String category;
  final String group;
  final String distance;
  final String address;
  final String hours;
  final String menu;
  final List<String> tags;
  final IconData icon;
  final Color color;

  const SoloPlace({
    required this.name,
    required this.category,
    required this.group,
    required this.distance,
    required this.address,
    required this.hours,
    required this.menu,
    required this.tags,
    required this.icon,
    required this.color,
  });
}

const _foodCategories = [
  '\uC804\uCCB4',
  '\uD55C\uC2DD',
  '\uC911\uC2DD',
  '\uC77C\uC2DD',
  '\uBD84\uC2DD',
  '\uC591\uC2DD',
  '\uCC0C\uAC1C',
  '\uAC04\uC2DD',
  '\uCE58\uD0A8',
  '\uC57C\uC2DD',
  '\uACE0\uAE30',
  '\uC0CC\uB4DC\uC704\uCE58',
  '\uB514\uC800\uD2B8',
];

const _soloPlaces = [
  SoloPlace(
    name: '\uD0C0\uC784\uC2A4\uD30C\uCF54',
    category: '\uBA55\uC2DC\uCF54 \uC591\uC2DD',
    group: '\uC591\uC2DD',
    distance: '\uB3C4\uBCF4 5\uBD84',
    address:
        '\uACBD\uAE30 \uC548\uC131\uC2DC \uB300\uB355\uBA74 \uB300\uD559\uB85C 25',
    hours: '11:00 ~ 21:30',
    menu: '\uBD80\uB9AC\uB610 \uC138\uD2B8 - 8,500\uC6D0',
    tags: [
      '1\uC778 \uBA54\uB274',
      '\uAC00\uC131\uBE44',
      '\uD0A4\uC624\uC2A4\uD06C \uC8FC\uBB38'
    ],
    icon: Icons.local_dining_rounded,
    color: Color(0xFFF06B6B),
  ),
  SoloPlace(
    name: '\uD55C\uC19F\uB3C4\uC2DC\uB77D',
    category: '\uD55C\uC2DD',
    group: '\uD55C\uC2DD',
    distance: '\uB3C4\uBCF4 5\uBD84',
    address:
        '\uACBD\uAE30 \uC548\uC131\uC2DC \uB300\uB355\uBA74 \uB300\uD559\uB85C 23',
    hours: '10:00 ~ 18:30',
    menu: '\uCE58\uC988 \uB3C8\uAE4C\uC2A4 \uB3C4\uC2DC\uB77D - 6,100\uC6D0',
    tags: [
      '1\uC778 \uBA54\uB274',
      '\uAC00\uC131\uBE44',
      '\uC0AC\uC7A5 \uCD94\uCC9C'
    ],
    icon: Icons.rice_bowl_rounded,
    color: Color(0xFFEF9F43),
  ),
  SoloPlace(
    name: '\uCEF5\uBC25\uC5F0\uAD6C\uC18C',
    category: '\uBD84\uC2DD \uCEF5\uBC25',
    group: '\uBD84\uC2DD',
    distance: '\uB3C4\uBCF4 3\uBD84',
    address:
        '\uACBD\uAE30 \uC548\uC131\uC2DC \uB300\uB355\uBA74 \uB300\uD559\uB85C 31 2\uCE35',
    hours: '11:00 ~ 21:00',
    menu: '\uC81C\uC721\uAE40\uCE58 \uCEF5\uBC25 - 6,500\uC6D0',
    tags: [
      '1\uC778 \uBA54\uB274',
      '\uAC00\uC131\uBE44',
      '\uBE60\uB978 \uC2DD\uC0AC'
    ],
    icon: Icons.takeout_dining_rounded,
    color: Color(0xFF46A67E),
  ),
  SoloPlace(
    name: '\uAC10\uB3D9\uAE4C\uC2A4',
    category: '\uB3C8\uAE4C\uC2A4',
    group: '\uC77C\uC2DD',
    distance: '\uB3C4\uBCF4 4\uBD84',
    address:
        '\uACBD\uAE30 \uC548\uC131\uC2DC \uB300\uB355\uBA74 \uB300\uD559\uB85C 21 1\uCE35',
    hours: '11:00 ~ 20:00',
    menu: '\uB3C8\uAE4C\uC2A4 \uC815\uC2DD - 7,900\uC6D0',
    tags: [
      '1\uC778 \uBA54\uB274',
      '\uB4E0\uB4E0\uD55C \uBA54\uB274',
      '\uC0AC\uC7A5 \uAC15\uCD94'
    ],
    icon: Icons.set_meal_rounded,
    color: Color(0xFF6A8DFF),
  ),
  SoloPlace(
    name: '\uBA85\uAC00\uAD50\uB3D9\uC9EC\uBF55',
    category: '\uC911\uC2DD',
    group: '\uC911\uC2DD',
    distance: '\uB3C4\uBCF4 6\uBD84',
    address:
        '\uACBD\uAE30 \uC548\uC131\uC2DC \uB300\uB355\uBA74 \uB300\uD559\uB85C 25',
    hours: '11:00 ~ 21:30',
    menu: '\uBC31\uC9EC\uBF55 - 10,000\uC6D0',
    tags: [
      '1\uC778 \uBA54\uB274',
      '\uAC00\uC131\uBE44',
      '\uD0A4\uC624\uC2A4\uD06C \uC8FC\uBB38'
    ],
    icon: Icons.ramen_dining_rounded,
    color: Color(0xFFD94F4F),
  ),
  SoloPlace(
    name: '\uB9C8\uC774\uCE58\uD0A8',
    category: '\uCE58\uD0A8',
    group: '\uCE58\uD0A8',
    distance: '\uB3C4\uBCF4 7\uBD84',
    address:
        '\uACBD\uAE30 \uC548\uC131\uC2DC \uB300\uB355\uBA74 \uC911\uC559\uAE38 18',
    hours: '12:00 ~ 23:00',
    menu: '\uC2DC\uB0B4\uCE58\uD0A8 1\uC778 \uC138\uD2B8 - 8,900\uC6D0',
    tags: ['1\uC778 \uC138\uD2B8', '\uBC30\uB2EC \uAC00\uB2A5', '\uC57C\uC2DD'],
    icon: Icons.fastfood_rounded,
    color: Color(0xFF8E6DE8),
  ),
];

String _formatDate(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}/ $month/ $day';
}

String _dDayText(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = target.difference(today).inDays;
  if (diff == 0) return 'D-Day';
  if (diff > 0) return 'D-$diff';
  return 'D+${diff.abs()}';
}

IconData _categoryIcon(String category) {
  return switch (category) {
    '\uD55C\uC2DD' => Icons.rice_bowl_rounded,
    '\uC911\uC2DD' => Icons.ramen_dining_rounded,
    '\uC77C\uC2DD' => Icons.set_meal_rounded,
    '\uBD84\uC2DD' => Icons.takeout_dining_rounded,
    '\uC591\uC2DD' => Icons.local_pizza_rounded,
    '\uCC0C\uAC1C' => Icons.soup_kitchen_rounded,
    '\uAC04\uC2DD' => Icons.local_dining_rounded,
    '\uCE58\uD0A8' => Icons.fastfood_rounded,
    '\uC57C\uC2DD' => Icons.nightlife_rounded,
    '\uACE0\uAE30' => Icons.outdoor_grill_rounded,
    '\uC0CC\uB4DC\uC704\uCE58' => Icons.lunch_dining_rounded,
    '\uB514\uC800\uD2B8' => Icons.icecream_rounded,
    _ => Icons.restaurant_rounded,
  };
}
