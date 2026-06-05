// lib/screens/explore_screen.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'meeting_detail_screen.dart';
import 'map/map_interface.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const _sortOptions = ['추천순', '최신순', '가까운 일정순', '인원 여유순'];
  static const _typeFilters = ['전체', '식당', '배달'];
  static const _categoryFilters = [
    '전체',
    '한식',
    '중식',
    '일식',
    '양식',
    '분식',
    '아시안',
    '치킨',
    '피자',
    '고기',
    '디저트',
    '카페',
  ];

  List<MeetingModel> _all = [];
  bool _loading = true;
  String _search = '';
  String _sortBy = _sortOptions.first;
  String _typeFilter = _typeFilters.first;
  String _categoryFilter = _categoryFilters.first;

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
      for (final m in meetings) {
        m.isJoined = myIds.contains(m.id);
        m.matchPercent = SupabaseService.calcMatch(myTags, m.tags);
      }
      setState(() {
        _all = meetings;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<MeetingModel> get _filtered {
    var list = List<MeetingModel>.from(_all);

    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list.where((m) {
        return m.title.toLowerCase().contains(q) ||
            m.description.toLowerCase().contains(q) ||
            m.location.toLowerCase().contains(q) ||
            (m.category ?? '').toLowerCase().contains(q) ||
            m.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    if (_typeFilter == '식당') {
      list = list.where((m) => m.type == MeetingType.restaurant).toList();
    } else if (_typeFilter == '배달') {
      list = list.where((m) => m.type == MeetingType.delivery).toList();
    }

    if (_categoryFilter != '전체') {
      list = list.where((m) => m.category == _categoryFilter).toList();
    }

    switch (_sortBy) {
      case '최신순':
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case '가까운 일정순':
        list.sort((a, b) => a.meetingTime.compareTo(b.meetingTime));
        break;
      case '인원 여유순':
        list.sort((a, b) {
          final aSeats = a.maxMembers - a.currentMembers;
          final bSeats = b.maxMembers - b.currentMembers;
          return bSeats.compareTo(aSeats);
        });
        break;
      case '추천순':
      default:
        list.sort((a, b) => b.matchPercent.compareTo(a.matchPercent));
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '정렬',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
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

  void _goDetail(MeetingModel meeting) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MeetingDetailScreen(meeting: meeting)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  const Text(
                    '모임 탐색',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MapScreen()),
                    ),
                    icon: const Icon(Icons.map_outlined),
                    color: AppColors.primary,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: '모임, 장소, 카테고리 검색',
                  hintStyle:
                      TextStyle(color: AppColors.textLight, fontSize: 14),
                  suffixIcon: Icon(Icons.search,
                      color: AppColors.textSecondary, size: 20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${filtered.length}개',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _FilterRow(
              values: _typeFilters,
              selected: _typeFilter,
              onSelected: (value) => setState(() => _typeFilter = value),
            ),
            const SizedBox(height: 8),
            _FilterRow(
              values: _categoryFilters,
              selected: _categoryFilter,
              onSelected: (value) => setState(() => _categoryFilter = value),
            ),
            const SizedBox(height: 4),
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
                                SizedBox(height: 160),
                                Center(
                                  child: Text(
                                    '조건에 맞는 모임이 없어요',
                                    style: TextStyle(
                                        color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, color: AppColors.divider),
                              itemBuilder: (_, i) => _CompactCard(
                                meeting: filtered[i],
                                onTap: () => _goDetail(filtered[i]),
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterRow({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: values.map((value) {
          final isSelected = selected == value;
          return GestureDetector(
            onTap: () => onSelected(value),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    const Icon(Icons.check, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CompactCard extends StatelessWidget {
  final MeetingModel meeting;
  final VoidCallback onTap;

  const _CompactCard({required this.meeting, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDelivery = meeting.type == MeetingType.delivery;
    final seatsLeft = meeting.maxMembers - meeting.currentMembers;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.bgGray,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(isDelivery ? '🛵' : '🍽️',
                    style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _MiniBadge(text: isDelivery ? '배달' : '식당', filled: true),
                      if (meeting.category?.isNotEmpty == true) ...[
                        const SizedBox(width: 5),
                        _MiniBadge(text: meeting.category!),
                      ],
                      if (meeting.matchPercent > 0) ...[
                        const SizedBox(width: 5),
                        Text(
                          '찰떡궁합 ${meeting.matchPercent}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 12, color: AppColors.textLight),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    meeting.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    children: meeting.tags
                        .take(3)
                        .map(
                          (t) => Text(
                            '#$t ',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.storefront_outlined,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          meeting.location.isEmpty ? '장소 미정' : meeting.location,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        '${meeting.meetingTime.month}/${meeting.meetingTime.day} ${meeting.meetingTime.hour}:${meeting.meetingTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.people_outline_rounded,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        seatsLeft > 0
                            ? '${meeting.currentMembers}/${meeting.maxMembers}명, $seatsLeft자리 남음'
                            : '모집 완료',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
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

class _MiniBadge extends StatelessWidget {
  final String text;
  final bool filled;

  const _MiniBadge({required this.text, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? AppColors.primary : AppColors.primaryBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: filled ? Colors.white : AppColors.primary,
        ),
      ),
    );
  }
}
