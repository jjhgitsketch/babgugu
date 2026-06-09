// lib/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tag_chip.dart';
import 'main_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final Set<String> _selectedTags = {};
  final _nameController = TextEditingController();
  int _age = 20;
  bool _loading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    setState(() => _loading = true);
    try {
      // Supabase Auth의 실제 userId 사용
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser == null) throw Exception('로그인이 필요해요');

      final user = UserModel(
        id: authUser.id, // Auth UUID 사용
        name: _nameController.text.trim().isEmpty
            ? '밥구구'
            : _nameController.text.trim(),
        tags: _selectedTags.toList(),
        age: _age,
      );
      currentUser = user;
      await SupabaseService.saveUser(user);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: List.generate(
                    3,
                    (i) => Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: i <= _currentPage
                                  ? AppColors.primary
                                  : AppColors.divider,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        )),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _WelcomePage(onNext: _nextPage),
                  _ProfilePage(
                    nameController: _nameController,
                    age: _age,
                    onAgeChanged: (v) => setState(() => _age = v),
                    onNext: _nextPage,
                  ),
                  _TagPage(
                    selectedTags: _selectedTags,
                    onToggle: (tag) => setState(() {
                      _selectedTags.contains(tag)
                          ? _selectedTags.remove(tag)
                          : _selectedTags.add(tag);
                    }),
                    onDone: _finish,
                    loading: _loading,
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

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20)),
            child: const Center(
                child: Text('🍽️', style: TextStyle(fontSize: 36))),
          ),
          const SizedBox(height: 32),
          const Text('밥구구',
              style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1.1,
                  letterSpacing: -1)),
          const SizedBox(height: 12),
          const Text('혼밥은 이제 그만.\n나와 잘 맞는 사람과 함께 먹어요.',
              style: TextStyle(
                  fontSize: 17, color: AppColors.textSecondary, height: 1.6)),
          const Spacer(),
          const _Row(emoji: '🎯', text: '관심사 기반 밥구구 매칭'),
          const SizedBox(height: 16),
          const _Row(emoji: '🍜', text: '식당 모임 & 배달 소분 모임'),
          const SizedBox(height: 16),
          const _Row(emoji: '💬', text: '실시간 채팅 & 더치페이 계산'),
          const Spacer(),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: onNext, child: const Text('프로필 설정하기'))),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String emoji, text;
  const _Row({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 14),
        Text(text,
            style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500)),
      ]);
}

class _ProfilePage extends StatelessWidget {
  final TextEditingController nameController;
  final int age;
  final ValueChanged<int> onAgeChanged;
  final VoidCallback onNext;

  const _ProfilePage(
      {required this.nameController,
      required this.age,
      required this.onAgeChanged,
      required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          const Text('기본 정보를\n알려주세요 👋',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1.2,
                  letterSpacing: -0.5)),
          const SizedBox(height: 36),
          const Text('이름',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(hintText: '이름을 입력해주세요'),
          ),
          const SizedBox(height: 24),
          Text('나이: $age세',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider)),
            child: Slider(
              value: age.toDouble(),
              min: 18,
              max: 40,
              divisions: 22,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.divider,
              onChanged: (v) => onAgeChanged(v.round()),
            ),
          ),
          const Spacer(),
          SizedBox(
              width: double.infinity,
              child:
                  ElevatedButton(onPressed: onNext, child: const Text('다음'))),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _TagPage extends StatelessWidget {
  final Set<String> selectedTags;
  final ValueChanged<String> onToggle;
  final VoidCallback onDone;
  final bool loading;

  const _TagPage(
      {required this.selectedTags,
      required this.onToggle,
      required this.onDone,
      required this.loading});

  @override
  Widget build(BuildContext context) {
    final categories = {
      '🍽️ 식사 성향': ['#조용히식사', '#대화좋아', '#조용한모임', '#혼밥'],
      '🥘 음식 취향': ['#한식파', '#일식파', '#중식파', '#양식파', '#채식', '#매운거좋아'],
      '🎯 관심사': ['#코딩', '#운동', '#독서', '#영화', '#게임', '#음악', '#여행', '#사진', '#카페'],
      '👤 나는': ['#대학생', '#직장인', '#새벽형', '#저녁형'],
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          const Text('나를 표현하는\n태그를 골라요 🏷️',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1.2,
                  letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text('${selectedTags.length}개 선택됨',
              style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: categories.entries
                    .map((e) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.key,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 10),
                            Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: e.value
                                    .map((tag) => TagChip(
                                        tag: tag,
                                        isSelected: selectedTags.contains(tag),
                                        onTap: () => onToggle(tag)))
                                    .toList()),
                            const SizedBox(height: 20),
                          ],
                        ))
                    .toList(),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (selectedTags.isNotEmpty && !loading) ? onDone : null,
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('밥구구 시작하기 🍽️'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
