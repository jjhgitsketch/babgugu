// lib/screens/edit_profile_screen.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _universityController;
  late final TextEditingController _departmentController;
  late final TextEditingController _studentIdController;
  late int _age;
  String _gender = '남';

  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  bool _saving = false;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    final user = currentUser!;
    _nicknameController = TextEditingController(text: user.nickname ?? '');
    _universityController = TextEditingController(text: user.university ?? '');
    _departmentController = TextEditingController(text: user.department ?? '');
    _studentIdController = TextEditingController(text: user.studentId ?? '');
    _age = user.age;
    _gender = user.gender ?? '남';
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _universityController.dispose();
    _departmentController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageName = picked.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '프로필 사진 변경',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            _PickerOption(
              icon: Icons.photo_library_outlined,
              label: '갤러리에서 선택',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 10),
            _PickerOption(
              icon: Icons.camera_alt_outlined,
              label: '카메라로 촬영',
              color: Colors.teal,
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            if (currentUser?.avatarUrl != null ||
                _pickedImageBytes != null) ...[
              const SizedBox(height: 10),
              _PickerOption(
                icon: Icons.delete_outline,
                label: '사진 제거',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _pickedImageBytes = null;
                    _pickedImageName = 'remove';
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = currentUser!;
      String? avatarUrl = user.avatarUrl;

      if (_pickedImageBytes != null && _pickedImageName != 'remove') {
        setState(() => _uploadingImage = true);
        final ext = _pickedImageName?.split('.').last ?? 'jpg';
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
        final uploaded = await SupabaseService.uploadAvatar(
          _pickedImageBytes!,
          fileName,
        );
        avatarUrl = uploaded ?? avatarUrl;
      } else if (_pickedImageName == 'remove') {
        avatarUrl = null;
      }

      final updated = UserModel(
        id: user.id,
        name: user.name,
        tags: user.tags,
        age: _age,
        nickname: _emptyToNull(_nicknameController.text),
        avatarUrl: avatarUrl,
        university: _emptyToNull(_universityController.text),
        department: _emptyToNull(_departmentController.text),
        studentId: _emptyToNull(_studentIdController.text),
        gender: _gender,
        schoolEmail: user.schoolEmail,
        studentVerified: user.studentVerified,
        studentVerifiedAt: user.studentVerifiedAt,
      );

      await SupabaseService.updateProfile(updated);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadingImage = false;
        });
      }
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUser!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _EditHeader(onSave: _saving ? null : _save),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _showImagePicker,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _AvatarPreview(
                            user: user,
                            pickedImageBytes: _pickedImageBytes,
                            pickedImageName: _pickedImageName,
                            uploading: _uploadingImage,
                          ),
                          Positioned(
                            right: 3,
                            bottom: 3,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 42),
                  const _SectionTitle(title: '기본 정보'),
                  const SizedBox(height: 14),
                  _ProfileField(
                    controller: _nicknameController,
                    hintText: user.displayName.isNotEmpty
                        ? user.displayName
                        : '배고픈 냠냐미',
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '설정하지 않으면 가입 시 입력한 이름이 표시돼요',
                    style: TextStyle(fontSize: 11, color: Color(0xFF999999)),
                  ),
                  const SizedBox(height: 16),
                  _GenderSelector(
                    value: _gender,
                    onChanged: (value) => setState(() => _gender = value),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    '나이 : $_age세',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 9),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 18),
                    ),
                    child: Slider(
                      value: _age.toDouble(),
                      min: 18,
                      max: 40,
                      divisions: 22,
                      activeColor: AppColors.primary,
                      inactiveColor: const Color(0xFFEAEAEA),
                      onChanged: (value) =>
                          setState(() => _age = value.round()),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle(title: '학교 정보'),
                  const SizedBox(height: 5),
                  const Text(
                    '입력하면 프로필에 학교 정보가 표시돼요',
                    style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
                  ),
                  const SizedBox(height: 15),
                  _ProfileField(
                    controller: _universityController,
                    hintText: '대학',
                    icon: Icons.school_outlined,
                  ),
                  const SizedBox(height: 12),
                  _ProfileField(
                    controller: _departmentController,
                    hintText: '학과',
                    icon: Icons.menu_book_outlined,
                  ),
                  const SizedBox(height: 12),
                  _ProfileField(
                    controller: _studentIdController,
                    hintText: '학번',
                    icon: Icons.badge_outlined,
                    keyboardType: TextInputType.text,
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

class TagEditScreen extends StatefulWidget {
  const TagEditScreen({super.key});

  @override
  State<TagEditScreen> createState() => _TagEditScreenState();
}

class _TagEditScreenState extends State<TagEditScreen> {
  late final Set<String> _selectedTags;
  bool _saving = false;

  static const Map<String, List<String>> _tagGroups = {
    '식사 성향': ['#조용한 대화', '#활발한 대화', '#밥만', '#혼밥', '#분밥'],
    '음식 취향': [
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
      '#채식',
      '#매운 음식',
    ],
    '관심사': [
      '#코딩',
      '#운동',
      '#여행',
      '#사진',
      '#게임',
      '#음악',
      '#독서',
      '#영화',
      '#애니',
      '#등산',
      '#반려견',
      '#카페',
    ],
    '나는': ['#내향형', '#외향형', '#저녁형', '#아침형', '#새벽형', '#대학생', '#직장인'],
  };

  static const Map<String, String> _legacyTagMap = {
    '#조용히식사': '#조용한 대화',
    '#대화좋아': '#활발한 대화',
    '#조용한모임': '#조용한 대화',
    '#한식파': '#한식',
    '#중식파': '#중식',
    '#일식파': '#일식',
    '#양식파': '#양식',
    '#매운거좋아': '#매운 음식',
  };

  static const Map<String, String> _sectionIcons = {
    '식사 성향': '🍽️',
    '음식 취향': '🥘',
    '관심사': '🎯',
    '나는': '👤',
  };

  @override
  void initState() {
    super.initState();
    _selectedTags = (currentUser?.tags ?? const [])
        .map((tag) => _legacyTagMap[tag] ?? tag)
        .toSet();
  }

  Future<void> _save() async {
    final user = currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final updated = UserModel(
        id: user.id,
        name: user.name,
        tags: _selectedTags.toList(),
        age: user.age,
        nickname: user.nickname,
        avatarUrl: user.avatarUrl,
        university: user.university,
        department: user.department,
        studentId: user.studentId,
        gender: user.gender,
        schoolEmail: user.schoolEmail,
        studentVerified: user.studentVerified,
        studentVerifiedAt: user.studentVerifiedAt,
      );
      await SupabaseService.updateProfile(updated);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('태그 저장 실패: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final canSave = _selectedTags.isNotEmpty && !_saving;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const _SimpleHeader(title: '태그 편집'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 27, 20, 24),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        '내 태그',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: Text(
                          '${_selectedTags.length}개 선택됨',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  ..._tagGroups.entries.map(
                    (entry) => _TagSectionBlock(
                      title: entry.key,
                      icon: _sectionIcons[entry.key] ?? '',
                      tags: entry.value,
                      selectedTags: _selectedTags,
                      onTap: _toggleTag,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: canSave ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canSave ? AppColors.primary : const Color(0xFFD9D9D9),
                    disabledBackgroundColor: const Color(0xFFD9D9D9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '저장하기',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
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

class _EditHeader extends StatelessWidget {
  final VoidCallback? onSave;

  const _EditHeader({required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 55,
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '\uD504\uB85C\uD544 \uD3B8\uC9D1',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onSave,
                style: TextButton.styleFrom(
                  minimumSize: const Size(52, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '\uC800\uC7A5',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleHeader extends StatelessWidget {
  final String title;

  const _SimpleHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 55,
      child: Row(
        children: [
          const SizedBox(width: 7),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 55),
        ],
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  final UserModel user;
  final Uint8List? pickedImageBytes;
  final String? pickedImageName;
  final bool uploading;

  const _AvatarPreview({
    required this.user,
    required this.pickedImageBytes,
    required this.pickedImageName,
    required this.uploading,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (uploading) {
      child = const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    } else if (pickedImageName == 'remove') {
      child = _DefaultAvatar(user: user, size: 100);
    } else if (pickedImageBytes != null) {
      child = Image.memory(pickedImageBytes!, fit: BoxFit.cover);
    } else if (user.avatarUrl != null) {
      child = Image.network(
        user.avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _DefaultAvatar(user: user, size: 100),
      );
    } else {
      child = _DefaultAvatar(user: user, size: 100);
    }

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD9D9D9), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  final UserModel user;
  final double size;

  const _DefaultAvatar({required this.user, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Colors.white,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        color: Colors.black,
        size: size * 0.58,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? icon;
  final TextInputType? keyboardType;

  const _ProfileField({
    required this.controller,
    required this.hintText,
    this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF9A9A9A),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: icon == null
              ? null
              : Icon(icon, size: 20, color: const Color(0xFF8E8E8E)),
          filled: true,
          fillColor: const Color(0xFFD9D9D9),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _GenderSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _GenderSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GenderButton(
            label: '남',
            selected: value == '남',
            onTap: () => onChanged('남'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GenderButton(
            label: '여',
            selected: value == '여',
            onTap: () => onChanged('여'),
          ),
        ),
      ],
    );
  }
}

class _GenderButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? AppColors.primary : Colors.white,
          foregroundColor: selected ? Colors.white : Colors.black,
          side: BorderSide(
            color: selected ? AppColors.primary : const Color(0xFFDADADA),
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        child: Text(label),
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PickerOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagSectionBlock extends StatelessWidget {
  final String title;
  final String icon;
  final List<String> tags;
  final Set<String> selectedTags;
  final ValueChanged<String> onTap;

  const _TagSectionBlock({
    required this.title,
    required this.icon,
    required this.tags,
    required this.selectedTags,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$icon $title',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 5,
            runSpacing: 6,
            children: tags
                .map(
                  (tag) => _TagChoiceChip(
                    label: tag,
                    selected: selectedTags.contains(tag),
                    onTap: () => onTap(tag),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _TagChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TagChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFEDEDED),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : const Color(0xFF4D4D4D),
          ),
        ),
      ),
    );
  }
}
