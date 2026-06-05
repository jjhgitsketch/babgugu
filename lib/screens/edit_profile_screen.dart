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
  late TextEditingController _nicknameController;
  late TextEditingController _universityController;
  late TextEditingController _departmentController;
  late TextEditingController _studentIdController;
  late Set<String> _selectedTags;
  late int _age;

  Uint8List? _pickedImageBytes;
  bool _loading = false;
  int _page = 0; // 0=기본정보, 1=태그선택

  // 태그 카테고리 (Image 2)
  final Map<String, List<String>> _tagCategories = {
    '🍽 식사 성향': ['#조용한 대화', '#활발한 대화', '#밥만', '#혼밥', '#대화는 자제'],
    '🍔 음식 취향': ['#한식', '#중식', '#일식', '#분식', '#채식', '#찜·탕', '#아시안', '#치킨', '#야식', '#고기', '#패스트푸드', '#카페·디저트', '#피자'],
    '🎯 관심사': ['#코딩', '#운동', '#여행', '#사진', '#게임', '#음악', '#독서', '#애니', '#등산', '#반려견'],
    '👤 나는': ['#내향형', '#외향형', '#이성적', '#감수성', '#현실적', '#직관적', '#계획적', '#자율적'],
  };

  @override
  void initState() {
    super.initState();
    final user = currentUser!;
    _nicknameController = TextEditingController(text: user.nickname ?? '');
    _universityController = TextEditingController(text: user.university ?? '');
    _departmentController = TextEditingController(text: user.department ?? '');
    _studentIdController = TextEditingController(text: user.studentId ?? '');
    _selectedTags = Set.from(user.tags);
    _age = user.age;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _universityController.dispose();
    _departmentController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
      if (picked == null) return;
      setState(() async => _pickedImageBytes = await picked.readAsBytes());
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final updated = currentUser!.copyWith(
        nickname: _nicknameController.text.trim(),
        age: _age,
        tags: _selectedTags.toList(),
        university: _universityController.text.trim(),
        department: _departmentController.text.trim(),
        studentId: _studentIdController.text.trim(),
      );
      await SupabaseService.updateProfile(updated);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('프로필 편집', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Text('저장', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: _page == 0 ? _buildBasicInfo() : _buildTagSelection(),
    );
  }

  // ─── 페이지1: 기본 정보 (Image 1) ───
  Widget _buildBasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아바타
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: _pickedImageBytes != null
                        ? ClipOval(child: Image.memory(_pickedImageBytes!, fit: BoxFit.cover))
                        : const Center(child: Icon(Icons.person_rounded, color: Colors.white, size: 44)),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 26, height: 26,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_rounded, size: 14, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // 기본 정보
          const Text('기본 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 16),

          const Text('닉네임', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _nicknameController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              filled: true, fillColor: AppColors.bgGray,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 4),
          const Text('설정하지 않으면 이름(랭뱅병)으로 표시돼요',
            style: TextStyle(fontSize: 11, color: AppColors.textLight)),
          const SizedBox(height: 16),

          // 나이 슬라이더
          Row(
            children: [
              Text('나이 : $_age세', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
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
              value: _age.toDouble(), min: 18, max: 40, divisions: 22,
              onChanged: (v) => setState(() => _age = v.round()),
            ),
          ),
          const SizedBox(height: 24),

          // 학교 정보
          const Text('학교 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('입력하면 프로필에 표시돼요', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 14),

          const Text('대학교', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _universityController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.school_outlined, size: 20, color: AppColors.textLight),
              filled: true, fillColor: AppColors.bgGray,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          const Text('학과', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _departmentController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.menu_book_outlined, size: 20, color: AppColors.textLight),
              filled: true, fillColor: AppColors.bgGray,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          const Text('학번', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _studentIdController,
            style: const TextStyle(fontSize: 14),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: AppColors.textLight),
              filled: true, fillColor: AppColors.bgGray,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 32),

          // 태그 선택으로 이동
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => setState(() => _page = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
              child: const Text('다음: 태그 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── 페이지2: 태그 선택 (Image 2) ───
  Widget _buildTagSelection() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('내 태그', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  '${_selectedTags.length}개 선택됨',
                  style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),

                ..._tagCategories.entries.map((entry) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: entry.value.map((tag) {
                        final isSelected = _selectedTags.contains(tag);
                        return GestureDetector(
                          onTap: () => setState(() {
                            isSelected ? _selectedTags.remove(tag) : _selectedTags.add(tag);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : AppColors.primaryBg,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                )),
              ],
            ),
          ),
        ),
        // 하단 저장 버튼
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('저장하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
