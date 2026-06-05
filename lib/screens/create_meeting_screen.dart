// lib/screens/create_meeting_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'map/map_interface.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});
  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  MeetingType _type = MeetingType.restaurant;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _deliveryAppController = TextEditingController();
  int _maxMembers = 3;
  bool _hasDutchPay = true;
  final Set<String> _selectedTags = {};
  bool _loading = false;
  double? _latitude;
  double? _longitude;
  String? _pickedAddress;
  String _category = '한식';

  // 날짜 선택 (오늘~3일)
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late List<DateTime> _dateOptions;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);
    _dateOptions = [
      now,
      now.add(const Duration(days: 1)),
      now.add(const Duration(days: 2))
    ];
  }

  DateTime get _scheduledAt => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _deliveryAppController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LocationResult>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _pickedAddress = result.address;
        if (_locationController.text.isEmpty) {
          _locationController.text = result.address;
        }
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('모임 제목을 입력해주세요'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final allSelectedTags =
          {...(currentUser?.tags ?? []), ..._selectedTags}.toList();
      final meeting = MeetingModel(
        id: '',
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        type: _type,
        tags: allSelectedTags,
        maxMembers: _maxMembers,
        currentMembers: 1,
        hasDutchPay: _hasDutchPay,
        location: _locationController.text.trim(),
        hostId: currentUser?.id ?? '',
        hostName: currentUser?.displayName ?? '',
        createdAt: DateTime.now(),
        scheduledAt: _scheduledAt,
        category: _category,
        latitude: _latitude,
        longitude: _longitude,
        address: _pickedAddress,
      );
      final created = await SupabaseService.createMeeting(meeting);
      if (created != null) {
        await Supabase.instance.client.from('meeting_members').upsert({
          'meeting_id': created.id,
          'user_id': SupabaseService.userId,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('모임이 생성됐어요! 🎉'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 배달 전용 태그
  static const _deliveryTags = [
    '#분식',
    '#중식',
    '#일식',
    '#한식',
    '#치킨',
    '#아식',
    '#고기',
    '#패스트푸드',
    '#피자',
    '#카페·디저트',
    '#소분원해요',
    '#최소주문금액'
  ];
  // 식당 전용 태그
  static const _restaurantTags = [
    '#코딩',
    '#운동',
    '#여행',
    '#사진',
    '#게임',
    '#음악',
    '#독서',
    '#애니',
    '#등산',
    '#반려견',
    '#한식파',
    '#양식파',
    '#중식파',
    '#일식',
    '#채식',
    '#조용한 대화',
    '#활발한 대화',
    '#아침형',
    '#새벽형',
    '#내향형',
    '#외향형'
  ];

  static const _restaurantCategories = [
    '한식',
    '중식',
    '일식',
    '양식',
    '분식',
    '아시안',
    '치킨',
    '고기',
    '카페'
  ];
  static const _deliveryCategories = [
    '분식',
    '중식',
    '일식',
    '한식',
    '치킨',
    '피자',
    '고기',
    '디저트',
    '카페'
  ];

  @override
  Widget build(BuildContext context) {
    final tags =
        _type == MeetingType.delivery ? _deliveryTags : _restaurantTags;
    final categories = _type == MeetingType.delivery
        ? _deliveryCategories
        : _restaurantCategories;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('모임 생성하기'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 모임 종류 ───
            const _Label('모임 종류'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _TypeCard(
                  emoji: '🍽',
                  label: '식당 모임',
                  subtitle: '같이 밥 먹어요',
                  isSelected: _type == MeetingType.restaurant,
                  onTap: () => setState(() {
                    _type = MeetingType.restaurant;
                    _category = _restaurantCategories.first;
                  }),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _TypeCard(
                  emoji: '🛵',
                  label: '배달 모임',
                  subtitle: '배달비 절약 or 소분해요',
                  isSelected: _type == MeetingType.delivery,
                  onTap: () => setState(() {
                    _type = MeetingType.delivery;
                    _category = _deliveryCategories.first;
                  }),
                )),
              ],
            ),
            const SizedBox(height: 24),

            // ─── 모임 이미지 (식당만) ───
            const _Label('음식 카테고리'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((category) {
                final isSelected = _category == category;
                return GestureDetector(
                  onTap: () => setState(() => _category = category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.bgGray,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color:
                            isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            if (_type == MeetingType.restaurant) ...[
              const _Label('모임 이미지'),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.camera_alt_outlined,
                          size: 18, color: AppColors.textSecondary),
                      SizedBox(width: 8),
                      Text('이미지 첨부하기',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ─── 모임 제목 ───
            const _Label('모임 제목'),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: _type == MeetingType.restaurant
                    ? '예) 초밥 먹으면서 영화 얘기 하실 분!'
                    : '예) 엽떡 소분하실 분 구해요!',
                hintStyle:
                    const TextStyle(color: AppColors.textLight, fontSize: 14),
                filled: true,
                fillColor: AppColors.bgGray,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      '시간 ${_selectedTime.format(context)}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const Spacer(),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ─── 모임 소개 ───
            const _Label('모임 소개'),
            const SizedBox(height: 10),
            TextField(
              controller: _descController,
              maxLines: 3,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: _type == MeetingType.restaurant
                    ? '어떤 모임인지 간단하게 소개해주세요.'
                    : '예) 소분할 용기  꼭! 들고 오셔야 돼요!',
                hintStyle:
                    const TextStyle(color: AppColors.textLight, fontSize: 14),
                filled: true,
                fillColor: AppColors.bgGray,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 20),

            // ─── 배달앱 (배달만) ───
            if (_type == MeetingType.delivery) ...[
              const _Label('배달앱'),
              const SizedBox(height: 10),
              TextField(
                controller: _deliveryAppController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '예) 배달의민족, 쿠팡이츠 등..',
                  hintStyle:
                      const TextStyle(color: AppColors.textLight, fontSize: 14),
                  filled: true,
                  fillColor: AppColors.bgGray,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ─── 위치 ───
            _Label(
                _type == MeetingType.restaurant ? '식당 위치' : '배달 수령지 / 소분 장소'),
            const SizedBox(height: 10),
            // 지도 버튼
            GestureDetector(
              onTap: _pickLocation,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _latitude != null
                      ? AppColors.primaryBg
                      : AppColors.bgGray,
                  borderRadius: BorderRadius.circular(12),
                  border: _latitude != null
                      ? Border.all(color: AppColors.primary)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 16,
                        color: _latitude != null
                            ? AppColors.primary
                            : AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                      _pickedAddress ?? '지도에서 위치 선택 가능',
                      style: TextStyle(
                          fontSize: 13,
                          color: _latitude != null
                              ? AppColors.primary
                              : AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    )),
                    if (_latitude != null)
                      GestureDetector(
                        onTap: () => setState(() {
                          _latitude = null;
                          _longitude = null;
                          _pickedAddress = null;
                        }),
                        child: const Icon(Icons.close,
                            size: 14, color: AppColors.textLight),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: _type == MeetingType.restaurant
                    ? '예) 식당 이름/어디 지점'
                    : '예) 식당 이름/어디 지점',
                hintStyle:
                    const TextStyle(color: AppColors.textLight, fontSize: 14),
                filled: true,
                fillColor: AppColors.bgGray,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),

            // ─── 날짜 ───
            Row(
              children: [
                const _Label('날짜 : '),
                ..._dateOptions.map((d) => GestureDetector(
                      onTap: () => setState(() => _selectedDate = d),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedDate.day == d.day
                              ? AppColors.primary
                              : AppColors.bgGray,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${d.month}/${d.day}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selectedDate.day == d.day
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )),
              ],
            ),
            const SizedBox(height: 20),

            // ─── 인원수 ───
            Row(
              children: [
                _Label('인원수 : $_maxMembers명'),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.divider,
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primary.withOpacity(0.15),
                trackHeight: 4,
              ),
              child: Slider(
                value: _maxMembers.toDouble(),
                min: 2,
                max: 8,
                divisions: 6,
                onChanged: (v) => setState(() => _maxMembers = v.round()),
              ),
            ),
            const SizedBox(height: 8),

            // ─── 더치페이 ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('더치페이',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        const Text('모임 종료 후 채팅방에서 1/N 정산 가능',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _hasDutchPay,
                    onChanged: (v) => setState(() => _hasDutchPay = v),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── 태그 추가 ───
            const _Label('태그 추가'),
            const SizedBox(height: 4),
            const Text('내 프로필 태그는 자동 포함돼요',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
                final isMyTag = currentUser?.tags.contains(tag) ?? false;
                final isSelected = _selectedTags.contains(tag) || isMyTag;
                return GestureDetector(
                  onTap: isMyTag
                      ? null
                      : () => setState(() {
                            isSelected
                                ? _selectedTags.remove(tag)
                                : _selectedTags.add(tag);
                          }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.bgGray,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      // 하단 버튼
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('모임 만들기 🍽',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary));
}

class _TypeCard extends StatelessWidget {
  final String emoji, label, subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  const _TypeCard(
      {required this.emoji,
      required this.label,
      required this.subtitle,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.primaryBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppColors.primary)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? Colors.white70
                          : AppColors.textSecondary)),
            ],
          ),
        ),
      );
}
