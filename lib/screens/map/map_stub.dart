// lib/screens/map/map_stub.dart
// 웹용 - 네이버 지도 없이 동작
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/meeting_card.dart';
import '../meeting_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<MeetingModel> _meetings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final meetings = (await SupabaseService.getMeetingsExcludingBlocked())
          .where((m) => !_isPastMeeting(m))
          .toList();
      final myIds = await SupabaseService.getMyMeetingIds();
      final myTags = currentUser?.tags ?? [];
      for (final m in meetings) {
        m.isJoined = myIds.contains(m.id);
        m.matchPercent = SupabaseService.calcMatch(myTags, m.tags);
      }
      setState(() {
        _meetings = meetings;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final withLocation = _meetings.where((m) => m.hasLocation).toList();
    final withoutLocation = _meetings.where((m) => !m.hasLocation).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('모임 위치'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load)
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: CustomScrollView(
                slivers: [
                  // 웹 안내 배너
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _WebBanner(),
                    ),
                  ),
                  if (withLocation.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                        child: Row(
                          children: [
                            const Text('📍 위치 설정된 모임',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text('${withLocation.length}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: MeetingCard(
                            meeting: withLocation[i],
                            onTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MeetingDetailScreen(
                                        meeting: withLocation[i]),
                                  ));
                              _load();
                            },
                          ),
                        ),
                        childCount: withLocation.length,
                      ),
                    ),
                  ],
                  if (withoutLocation.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                        child: Row(
                          children: [
                            Text('모든 모임',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                            SizedBox(width: 6),
                            Text('위치 미설정 포함',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: MeetingCard(
                            meeting: withoutLocation[i],
                            onTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MeetingDetailScreen(
                                        meeting: withoutLocation[i]),
                                  ));
                              _load();
                            },
                          ),
                        ),
                        childCount: withoutLocation.length,
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
    );
  }
}

class _WebBanner extends StatelessWidget {
  const _WebBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.tagBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            Text('🗺️', style: TextStyle(fontSize: 24)),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('지도 보기는 앱에서 이용해요',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                  Text('모임 만들 때 위치를 설정하면 지도에 표시돼요',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
}

// 웹용 LocationPickerScreen (텍스트 입력)
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _manualController = TextEditingController();

  static const _quickLocations = [
    {'name': '강남역', 'lat': 37.4979, 'lng': 127.0276},
    {'name': '홍대입구역', 'lat': 37.5572, 'lng': 126.9258},
    {'name': '신촌', 'lat': 37.5596, 'lng': 126.9425},
    {'name': '건대입구역', 'lat': 37.5403, 'lng': 127.0695},
    {'name': '혜화(대학로)', 'lat': 37.5822, 'lng': 127.0019},
    {'name': '이태원', 'lat': 37.5341, 'lng': 126.9942},
    {'name': '여의도', 'lat': 37.5217, 'lng': 126.9245},
    {'name': '종로', 'lat': 37.5703, 'lng': 126.9920},
    {'name': '신림', 'lat': 37.4843, 'lng': 126.9293},
    {'name': '수원역', 'lat': 37.2659, 'lng': 127.0002},
  ];

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  void _confirm() {
    final text = _manualController.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(
        context, LocationResult(latitude: 0, longitude: 0, address: text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('위치 설정'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('위치 직접 입력',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualController,
                    decoration: const InputDecoration(
                      hintText: '예) 학교 앞 김밥천국',
                      prefixIcon: Icon(Icons.place_outlined,
                          size: 18, color: AppColors.textLight),
                    ),
                    onSubmitted: (_) => _confirm(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(onPressed: _confirm, child: const Text('확인')),
              ],
            ),
            const SizedBox(height: 24),
            const Text('빠른 선택',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickLocations
                  .map((loc) => GestureDetector(
                        onTap: () => Navigator.pop(
                            context,
                            LocationResult(
                              latitude: loc['lat'] as double,
                              longitude: loc['lng'] as double,
                              address: loc['name'] as String,
                            )),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.place_outlined,
                                  size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(loc['name'] as String,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationResult {
  final double latitude;
  final double longitude;
  final String address;
  const LocationResult(
      {required this.latitude, required this.longitude, required this.address});
}

bool _isPastMeeting(MeetingModel meeting) {
  if (meeting.status == MeetingStatus.completed) return true;
  final today = DateUtils.dateOnly(DateTime.now());
  final meetingDay = DateUtils.dateOnly(meeting.meetingTime);
  return meetingDay.isBefore(today);
}
