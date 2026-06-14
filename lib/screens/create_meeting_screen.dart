// lib/screens/create_meeting_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'map/map_interface.dart';
import 'meeting_detail_screen.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  static const _foodTags = [
    '#한식',
    '#중식',
    '#일식',
    '#분식',
    '#양식',
    '#찜・탕',
    '#아시안',
    '#치킨',
    '#야식',
    '#고기',
    '#패스트푸드',
    '#디저트',
  ];
  static const _interestTags = [
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
  ];
  static const _deliveryTags = [
    '#한식',
    '#중식',
    '#일식',
    '#분식',
    '#양식',
    '#찜・탕',
    '#아시안',
    '#치킨',
    '#야식',
    '#고기',
    '#패스트푸드',
    '#디저트',
    '#피자',
    '#소분원해요',
    '#같이시켜요',
  ];

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final _deliveryAppController = TextEditingController();
  final _baeminTogetherUrlController = TextEditingController();

  MeetingType _type = MeetingType.restaurant;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);
  int _maxMembers = 3;
  bool _hasDutchPay = true;
  bool _useBaeminTogether = true;
  bool _loading = false;
  Uint8List? _meetingImageBytes;
  String? _meetingImageName;
  final Set<String> _selectedTags = {'#한식'};

  double? _latitude;
  double? _longitude;
  String? _pickedAddress;

  bool get _isDelivery => _type == MeetingType.delivery;
  int get _minMembers => _isDelivery ? 2 : 3;
  bool get _canSubmit {
    final hasTitle = _titleController.text.trim().isNotEmpty;
    final hasLocation = _locationController.text.trim().isNotEmpty;
    final hasDeliveryApp =
        !_isDelivery || _deliveryAppController.text.trim().isNotEmpty;
    final hasBaeminTogetherUrl = !_isDelivery ||
        !_useBaeminTogether ||
        _baeminTogetherUrlController.text.trim().isNotEmpty;
    return hasTitle &&
        hasLocation &&
        hasDeliveryApp &&
        hasBaeminTogetherUrl &&
        !_loading;
  }

  String get _category {
    final selectedFood = (_isDelivery ? _deliveryTags : _foodTags)
        .where(_selectedTags.contains)
        .toList();
    return selectedFood.isEmpty
        ? (_isDelivery ? '배달' : '식당')
        : selectedFood.first.replaceFirst('#', '');
  }

  DateTime get _scheduledAt {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onFormChanged);
    _locationController.addListener(_onFormChanged);
    _deliveryAppController.addListener(_onFormChanged);
    _baeminTogetherUrlController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _deliveryAppController.dispose();
    _baeminTogetherUrlController.dispose();
    super.dispose();
  }

  void _onFormChanged() => setState(() {});

  void _selectType(MeetingType type) {
    setState(() {
      _type = type;
      _selectedTags.clear();
      _selectedTags.add(type == MeetingType.delivery ? '#분식' : '#한식');
      if (_maxMembers < _minMembers) _maxMembers = _minMembers;
    });
  }

  Future<void> _pickMeetingImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _meetingImageBytes = bytes;
        _meetingImageName = picked.name;
      });
    } catch (e) {
      if (mounted) _showSnack('이미지를 불러오지 못했어요: $e', isError: true);
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LocationResult>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result == null) return;

    setState(() {
      _latitude = result.latitude;
      _longitude = result.longitude;
      _pickedAddress = result.address;
      if (_locationController.text.trim().isEmpty) {
        _locationController.text = result.address;
      }
    });
  }

  Future<void> _pickTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (result != null) setState(() => _selectedTime = result);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() => _loading = true);
    try {
      final allSelectedTags = {
        ...(currentUser?.tags ?? const <String>[]),
        ..._selectedTags,
        if (_isDelivery && _useBaeminTogether) '#함께주문',
      }.toList();
      final imageUrl = _meetingImageBytes == null
          ? null
          : await SupabaseService.uploadMeetingImage(
              _meetingImageBytes!,
              _meetingImageName ?? 'meeting.jpg',
            );

      final descriptionParts = [
        _descController.text.trim(),
        if (_isDelivery && _deliveryAppController.text.trim().isNotEmpty)
          '배달앱: ${_deliveryAppController.text.trim()}',
        if (_isDelivery && _useBaeminTogether) '배달의 민족-함께주문 가능',
      ].where((text) => text.isNotEmpty).join('\n');

      final meeting = MeetingModel(
        id: '',
        title: _titleController.text.trim(),
        description: descriptionParts,
        type: _type,
        tags: allSelectedTags,
        maxMembers: _maxMembers,
        currentMembers: 1,
        hasDutchPay: _hasDutchPay,
        location: _locationController.text.trim(),
        hostId: currentUser?.id ?? '',
        hostName: currentUser?.displayName ?? currentUser?.name ?? '',
        createdAt: DateTime.now(),
        scheduledAt: _scheduledAt,
        category: _category,
        latitude: _latitude,
        longitude: _longitude,
        address: _pickedAddress,
        imageUrl: imageUrl,
        baeminTogetherUrl: _isDelivery && _useBaeminTogether
            ? _baeminTogetherUrlController.text.trim()
            : null,
      );

      final created = await SupabaseService.createMeeting(meeting);
      if (created != null) {
        await Supabase.instance.client.from('meeting_members').upsert({
          'meeting_id': created.id,
          'user_id': SupabaseService.userId,
        });
        created.isJoined = true;
      }

      if (!mounted) return;
      if (created == null) {
        _showSnack('모임을 생성하지 못했어요.', isError: true);
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => MeetingDetailScreen(meeting: created)),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('오류: $e', isError: true);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('모임 생성하기'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFDADADA)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 353),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('모임 종류', fontSize: 18),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TypeCard(
                        emoji: '🍽️',
                        title: '식당 모임',
                        subtitle: '같이 밥 먹어요',
                        selected: !_isDelivery,
                        onTap: () => _selectType(MeetingType.restaurant),
                      ),
                    ),
                    const SizedBox(width: 17),
                    Expanded(
                      child: _TypeCard(
                        emoji: '🛵',
                        title: '배달 모임',
                        subtitle: '배달비 절약 or 소분해요',
                        selected: _isDelivery,
                        onTap: () => _selectType(MeetingType.delivery),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _isDelivery ? 57 : 59),
                if (!_isDelivery) ...[
                  const _SectionTitle('모임 이미지'),
                  const SizedBox(height: 9),
                  _ImageAttachButton(
                    imageBytes: _meetingImageBytes,
                    fileName: _meetingImageName,
                    onTap: _pickMeetingImage,
                    onRemove: () => setState(() {
                      _meetingImageBytes = null;
                      _meetingImageName = null;
                    }),
                  ),
                  const SizedBox(height: 39),
                ],
                const _SectionTitle('모임 제목'),
                const SizedBox(height: 7),
                _TextInput(
                  controller: _titleController,
                  hintText: _isDelivery
                      ? '예) 엽떡 소분하실 분 구해요!'
                      : '예) 초밥 먹으면서 영화 얘기 하실 분!',
                ),
                const SizedBox(height: 33),
                const _SectionTitle('모임 소개'),
                const SizedBox(height: 7),
                _TextInput(
                  controller: _descController,
                  hintText: _isDelivery
                      ? '예) 소분할 용기 꼭! 들고 오셔야 돼요!'
                      : '어떤 모임인지 간단하게 소개해주세요.',
                  height: _isDelivery ? 69 : 86,
                  maxLines: 4,
                ),
                const SizedBox(height: 33),
                if (_isDelivery) ...[
                  const _SectionTitle('배달앱'),
                  const SizedBox(height: 11),
                  SizedBox(
                    width: 155,
                    child: _TextInput(
                      controller: _deliveryAppController,
                      hintText: '예) 배달의민족',
                    ),
                  ),
                  const SizedBox(height: 34),
                  _BaeminTogetherRow(
                    value: _useBaeminTogether,
                    onChanged: (value) =>
                        setState(() => _useBaeminTogether = value),
                  ),
                  if (_useBaeminTogether) ...[
                    const SizedBox(height: 10),
                    _TextInput(
                      controller: _baeminTogetherUrlController,
                      hintText: '배민 함께주문 링크를 붙여넣어 주세요',
                      keyboardType: TextInputType.url,
                    ),
                  ],
                  const SizedBox(height: 33),
                ],
                _SectionTitle(_isDelivery ? '배달 수령지 / 소분 장소' : '식당 위치'),
                const SizedBox(height: 9),
                _LocationPickButton(
                  selected: _latitude != null,
                  label: _latitude == null ? '지도에서 위치 선택 가능' : '위치 선택 완료',
                  onTap: _pickLocation,
                ),
                const SizedBox(height: 10),
                _TextInput(
                  controller: _locationController,
                  hintText:
                      _isDelivery ? '예) 중앙대학교 다빈치 캠퍼스 후문 앞' : '예) 식당 이름/어디 지점',
                ),
                const SizedBox(height: 33),
                Row(
                  children: [
                    const _SectionTitle('날짜 :'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DateChips(
                        selectedDate: _selectedDate,
                        onTap: (date) => setState(() => _selectedDate = date),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const _SectionTitle('시간 :'),
                    const SizedBox(width: 12),
                    _TimeButton(
                      label: _selectedTime.format(context),
                      onTap: _pickTime,
                    ),
                  ],
                ),
                const SizedBox(height: 33),
                _SectionTitle('인원수 : $_maxMembers명'),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: const Color(0xFFFFD7D5),
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.12),
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: _maxMembers.toDouble(),
                    min: _minMembers.toDouble(),
                    max: 8,
                    divisions: 8 - _minMembers,
                    label: '$_maxMembers명',
                    onChanged: (value) =>
                        setState(() => _maxMembers = value.round()),
                  ),
                ),
                if (!_isDelivery) ...[
                  const SizedBox(height: 7),
                  const Text(
                    '*최소 3명부터 가능해요*',
                    style: TextStyle(fontSize: 11, color: Color(0xFFA1A1A1)),
                  ),
                  const SizedBox(height: 33),
                  _DutchPayRow(
                    value: _hasDutchPay,
                    onChanged: (value) => setState(() => _hasDutchPay = value),
                  ),
                  const SizedBox(height: 33),
                  const _SectionTitle('태그 추가'),
                  const SizedBox(height: 7),
                  const Text(
                    '내 프로필 태그는 자동 포함돼요',
                    style: TextStyle(fontSize: 11, color: Color(0xFFA1A1A1)),
                  ),
                  const SizedBox(height: 24),
                  _TagSection(
                    title: '🥘 음식 취향',
                    tags: _foodTags,
                    selectedTags: _selectedTags,
                    onTap: _toggleTag,
                  ),
                  const SizedBox(height: 24),
                  _TagSection(
                    title: '🎯 관심사',
                    tags: _interestTags,
                    selectedTags: _selectedTags,
                    onTap: _toggleTag,
                  ),
                ] else ...[
                  const SizedBox(height: 33),
                  const _SectionTitle('태그 선택'),
                  const SizedBox(height: 18),
                  _TagSection(
                    tags: _deliveryTags,
                    selectedTags: _selectedTags,
                    onTap: _toggleTag,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(25, 10, 25, 10),
          child: SizedBox(
            height: 55,
            child: ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: const Color(0xFFD9D9D9),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      '모임 만들기 ${_isDelivery ? '🛵' : '🍽️'}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final double fontSize;

  const _SectionTitle(this.title, {this.fontSize = 16});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: Colors.black,
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 112,
        padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFFFF0EF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageAttachButton extends StatelessWidget {
  final Uint8List? imageBytes;
  final String? fileName;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ImageAttachButton({
    required this.imageBytes,
    required this.fileName,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (imageBytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              imageBytes!,
              width: double.infinity,
              height: 118,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.54),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child:
                      Icon(Icons.close_rounded, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
          if (fileName?.isNotEmpty == true)
            Positioned(
              left: 9,
              right: 45,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.46),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  fileName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),
        ],
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_rounded,
                  size: 18, color: Color(0xFFA1A1A1)),
              SizedBox(width: 3),
              Text(
                '이미지 첨부하기',
                style: TextStyle(fontSize: 11, color: Color(0xFFA1A1A1)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final double height;
  final TextInputType? keyboardType;

  const _TextInput({
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.height = 44,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13, color: Colors.black),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFA1A1A1)),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: Color(0xFFDADADA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.3),
          ),
        ),
      ),
    );
  }
}

class _LocationPickButton extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _LocationPickButton({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 27,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(
          selected ? Icons.check_circle : Icons.location_on_rounded,
          size: 17,
          color: const Color(0xFFA1A1A1),
        ),
        label: Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: Color(0xFFA1A1A1)),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.only(left: 3, right: 8),
          side: const BorderSide(color: Color(0xFFD9D9D9)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
      ),
    );
  }
}

class _DateChips extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onTap;

  const _DateChips({required this.selectedDate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dates = List.generate(
      3,
      (index) => DateTime(today.year, today.month, today.day + index),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final date in dates) ...[
            _DateChip(
              date: date,
              selected: _sameDay(date, selectedDate),
              onTap: () => onTap(date),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  const _DateChip({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 71,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0EF),
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: AppColors.primary) : null,
        ),
        child: Text(
          '${date.month}/${date.day}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TimeButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 141,
      height: 38,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFDADADA)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 17, color: Colors.black),
          ],
        ),
      ),
    );
  }
}

class _DutchPayRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DutchPayRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      title: '더치페이',
      subtitle: '모임 종료 후 채팅방에서 1/N 정산 가능',
      value: value,
      onChanged: onChanged,
    );
  }
}

class _BaeminTogetherRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BaeminTogetherRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      title: '배달의 민족-함께주문',
      subtitle: '모임 채팅방에서 배민 연동 가능해요',
      value: value,
      onChanged: onChanged,
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.fromLTRB(9, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD9D9D9)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFFA1A1A1)),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: const Color(0xFFD9D9D9),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD9D9D9),
          ),
        ],
      ),
    );
  }
}

class _TagSection extends StatelessWidget {
  final String? title;
  final List<String> tags;
  final Set<String> selectedTags;
  final ValueChanged<String> onTap;

  const _TagSection({
    this.title,
    required this.tags,
    required this.selectedTags,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title!, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 14),
        ],
        Wrap(
          spacing: 5,
          runSpacing: 6,
          children: tags.map((tag) {
            final selected = selectedTags.contains(tag);
            return GestureDetector(
              onTap: () => onTap(tag),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : const Color(0xFFEDEDED),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFF33363F),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
