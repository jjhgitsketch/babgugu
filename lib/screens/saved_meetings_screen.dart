// lib/screens/saved_meetings_screen.dart
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/meeting_image.dart';
import 'meeting_detail_screen.dart';

class SavedMeetingsScreen extends StatefulWidget {
  const SavedMeetingsScreen({super.key});

  @override
  State<SavedMeetingsScreen> createState() => _SavedMeetingsScreenState();
}

class _SavedMeetingsScreenState extends State<SavedMeetingsScreen> {
  List<MeetingModel> _meetings = [];
  Set<String> _myMeetingIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getSavedMeetings(),
        SupabaseService.getMyMeetingIds(),
      ]);
      final meetings = results[0] as List<MeetingModel>;
      final myIds = results[1] as Set<String>;
      final myTags = currentUser?.tags ?? [];

      for (final meeting in meetings) {
        meeting.isJoined = myIds.contains(meeting.id);
        meeting.matchPercent = SupabaseService.calcMatch(myTags, meeting.tags);
      }

      if (!mounted) return;
      setState(() {
        _meetings = meetings;
        _myMeetingIds = myIds;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장한 모임을 불러오지 못했어요: $e')),
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

  Future<void> _unsave(MeetingModel meeting) async {
    setState(() => _meetings.removeWhere((item) => item.id == meeting.id));
    try {
      await SupabaseService.unsaveMeeting(meeting.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _meetings.add(meeting));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 취소에 실패했어요: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _PlainHeader(title: '저장한 모임'),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: _meetings.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 210),
                                _EmptySavedState(),
                              ],
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 23, 20, 96),
                              itemCount: _meetings.length,
                              separatorBuilder: (_, __) => const SizedBox(
                                height: 14,
                              ),
                              itemBuilder: (context, index) {
                                final meeting = _meetings[index];
                                return _SavedMeetingCard(
                                  meeting: meeting,
                                  joined: _myMeetingIds.contains(meeting.id),
                                  onTap: () => _openMeeting(meeting),
                                  onUnsave: () => _unsave(meeting),
                                );
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

class _PlainHeader extends StatelessWidget {
  final String title;

  const _PlainHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8E8E8))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _SavedMeetingCard extends StatelessWidget {
  final MeetingModel meeting;
  final bool joined;
  final VoidCallback onTap;
  final VoidCallback onUnsave;

  const _SavedMeetingCard({
    required this.meeting,
    required this.joined,
    required this.onTap,
    required this.onUnsave,
  });

  @override
  Widget build(BuildContext context) {
    final isDelivery = meeting.type == MeetingType.delivery;
    final typeLabel = isDelivery ? '배달' : '식당';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            MeetingImage(
              meeting: meeting,
              width: 104,
              height: double.infinity,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(13),
              ),
              fallbackColor: isDelivery
                  ? const Color(0xFFE9F2FF)
                  : const Color(0xFFFFECE5),
              iconSize: 42,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 24,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            typeLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          joined
                              ? Icons.check_circle_rounded
                              : Icons.auto_awesome,
                          size: 15,
                          color: joined ? Colors.green : Colors.black,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          joined ? '참여중' : '찰떡궁합 ${meeting.matchPercent}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: joined ? Colors.green : Colors.black,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: onUnsave,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                          icon: const Icon(
                            Icons.bookmark_rounded,
                            color: AppColors.primary,
                          ),
                          tooltip: '저장 취소',
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
                    const SizedBox(height: 5),
                    Text(
                      _tagLine(meeting.tags),
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
                        const Icon(Icons.location_on_outlined, size: 15),
                        const SizedBox(width: 2),
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
                        const Icon(Icons.person_outline_rounded, size: 15),
                        const SizedBox(width: 2),
                        Text(
                          '${meeting.currentMembers}/${meeting.maxMembers}명',
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

class _EmptySavedState extends StatelessWidget {
  const _EmptySavedState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: const BoxDecoration(
            color: AppColors.primaryBg,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.bookmark_border_rounded,
            color: AppColors.primary,
            size: 32,
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          '저장한 모임이 없어요',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        const Text(
          '마음에 드는 모임을 저장하면 여기에서 모아볼 수 있어요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

String _tagLine(List<String> tags) {
  if (tags.isEmpty) return '#밥구구';
  return tags
      .take(3)
      .map((tag) => tag.startsWith('#') ? tag : '#$tag')
      .join(' ');
}
