import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'map/map_interface.dart';
import 'meeting_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const _sortOptions = ['최신순', '추천순', '가까운 일정순', '인원 여유순'];
  static const _filterOptions = ['전체 장소', '1인 식당', '진행 중 모임'];

  List<MeetingModel> _all = [];
  bool _loading = true;
  String _search = '';
  String _sortBy = _sortOptions.first;
  String _filter = _filterOptions.first;

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
      final myTags = currentUser?.tags ?? [];

      for (final meeting in meetings) {
        meeting.isJoined = myIds.contains(meeting.id);
        meeting.matchPercent = SupabaseService.calcMatch(myTags, meeting.tags);
      }

      if (!mounted) return;
      setState(() {
        _all = meetings;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<MeetingModel> get _filtered {
    var list = List<MeetingModel>.from(_all);
    final query = _search.trim().toLowerCase();

    if (query.isNotEmpty) {
      list = list.where((meeting) {
        return meeting.title.toLowerCase().contains(query) ||
            meeting.description.toLowerCase().contains(query) ||
            meeting.location.toLowerCase().contains(query) ||
            (meeting.category ?? '').toLowerCase().contains(query) ||
            meeting.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    if (_filter == '1인 식당') {
      list = list.where((meeting) {
        return meeting.maxMembers <= 2 ||
            meeting.tags.any((tag) => tag.contains('혼밥')) ||
            meeting.title.contains('혼밥');
      }).toList();
    } else if (_filter == '진행 중 모임') {
      list = list
          .where((meeting) => meeting.currentMembers < meeting.maxMembers)
          .toList();
    }

    switch (_sortBy) {
      case '추천순':
        list.sort((a, b) => b.matchPercent.compareTo(a.matchPercent));
        break;
      case '가까운 일정순':
        list.sort((a, b) => a.meetingTime.compareTo(b.meetingTime));
        break;
      case '인원 여유순':
        list.sort((a, b) => (b.maxMembers - b.currentMembers)
            .compareTo(a.maxMembers - a.currentMembers));
        break;
      case '최신순':
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  Future<void> _showSortSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 45,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D9D9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text('정렬',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ..._sortOptions.map(
                (option) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(option),
                  trailing: _sortBy == option
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, option),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) setState(() => _sortBy = selected);
  }

  Future<void> _openDetail(MeetingModel meeting) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MeetingDetailScreen(meeting: meeting)),
    );
    _load();
  }

  void _openMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapScreen()),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ExploreModeHeader(onMapTap: _openMap),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: _SearchField(
                  onChanged: (value) => setState(() => _search = value)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _showSortSheet,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _sortBy,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${filtered.length}개',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ExploreFilterRow(
              selected: _filter,
              onSelected: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: filtered.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 170),
                                Center(
                                  child: Text(
                                    '조건에 맞는 모임이 없어요.',
                                    style: TextStyle(
                                        color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 27,
                                color: Color(0xFFE0E0E0),
                              ),
                              itemBuilder: (_, index) {
                                final meeting = filtered[index];
                                return _ExploreMeetingRow(
                                  meeting: meeting,
                                  imageIndex: index,
                                  onTap: () => _openDetail(meeting),
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

class _ExploreModeHeader extends StatelessWidget {
  final VoidCallback onMapTap;

  const _ExploreModeHeader({required this.onMapTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onMapTap,
              behavior: HitTestBehavior.opaque,
              child: const Text(
                '지도로 보기',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF909090),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '리스트로 보기',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Container(width: 96, height: 3, color: Colors.black),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: '모임, 장소, 카테고리 검색',
          hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          suffixIcon: const Icon(Icons.search_rounded,
              color: AppColors.textSecondary, size: 29),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD9D9D9), width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
          ),
        ),
      ),
    );
  }
}

class _ExploreFilterRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _ExploreFilterRow({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 23,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _ExploreScreenState._filterOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final value = _ExploreScreenState._filterOptions[index];
          final active = selected == value;
          final icon = switch (value) {
            '전체 장소' => Icons.explore_rounded,
            '1인 식당' => Icons.person_rounded,
            _ => Icons.groups_rounded,
          };
          return GestureDetector(
            onTap: () => onSelected(value),
            child: Container(
              width: 76,
              height: 23,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color:
                    active ? const Color(0xFF444EF8) : const Color(0xFFDDE5F3),
                borderRadius: BorderRadius.circular(19),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: value == '전체 장소' ? 14 : 12,
                      color: active ? Colors.white : const Color(0xFF444EF8)),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w800,
                        color: active ? Colors.white : const Color(0xFF444EF8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ExploreMeetingRow extends StatelessWidget {
  final MeetingModel meeting;
  final int imageIndex;
  final VoidCallback onTap;

  const _ExploreMeetingRow({
    required this.meeting,
    required this.imageIndex,
    required this.onTap,
  });

  static const _imageColors = [
    Color(0xFFFFECE5),
    Color(0xFFE9F2FF),
    Color(0xFFFFF2D7),
    Color(0xFFEAF7EE),
    Color(0xFFF1ECFF),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 128,
        child: Row(
          children: [
            Container(
              width: 105,
              height: 118,
              decoration: BoxDecoration(
                color: _imageColors[imageIndex % _imageColors.length],
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Icon(_meetingIcon(meeting),
                  size: 42, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          meeting.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded, size: 22),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tagLine(meeting.tags),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 10, color: Color(0xFF909090)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 15),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          meeting.location.isEmpty ? '장소 미정' : meeting.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 15),
                      const SizedBox(width: 2),
                      Text(_shortDate(meeting.meetingTime),
                          style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 12),
                      const Icon(Icons.person_outline_rounded, size: 15),
                      const SizedBox(width: 2),
                      Text('${meeting.currentMembers} / ${meeting.maxMembers}명',
                          style: const TextStyle(fontSize: 11)),
                      const Spacer(),
                      const Icon(Icons.auto_awesome, size: 13),
                      const SizedBox(width: 2),
                      Text('찰떡궁합 ${meeting.matchPercent}%',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w900)),
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

IconData _meetingIcon(MeetingModel meeting) {
  final text =
      '${meeting.title} ${meeting.category ?? ''} ${meeting.tags.join(' ')}';
  if (text.contains('초밥') || text.contains('일식')) {
    return Icons.set_meal_rounded;
  }
  if (text.contains('마라') || text.contains('중식')) {
    return Icons.ramen_dining_rounded;
  }
  if (text.contains('파스타') || text.contains('양식')) {
    return Icons.local_pizza_rounded;
  }
  if (text.contains('감자탕') || text.contains('찌개')) {
    return Icons.soup_kitchen_rounded;
  }
  if (text.contains('햄버거') || text.contains('샌드위치')) {
    return Icons.lunch_dining_rounded;
  }
  return meeting.type == MeetingType.delivery
      ? Icons.delivery_dining_rounded
      : Icons.restaurant_rounded;
}

String _tagLine(List<String> tags) {
  if (tags.isEmpty) return '#밥구구';
  return tags
      .take(3)
      .map((tag) => tag.startsWith('#') ? tag : '#$tag')
      .join(' ');
}

String _shortDate(DateTime date) {
  final local = date.toLocal();
  return '${local.month}/${local.day}';
}
