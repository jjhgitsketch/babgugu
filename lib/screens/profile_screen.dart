// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'edit_profile_screen.dart';
import 'auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final user = currentUser;
    final tags = user?.tags ?? [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // 헤더
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Text('내 프로필',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.store_outlined,
                          color: AppColors.textPrimary, size: 24),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),

            // 프로필 카드
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    // 아바타
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.person_rounded,
                            color: Colors.white, size: 32),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? '닉네임',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        const Text('22세',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 프로필 편집 버튼
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EditProfileScreen()));
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.bgGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 6),
                        Text('프로필 편집',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // 내 태그
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('내 태그',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('이 태그를 기반으로 모임이 추천돼요',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags
                          .map((t) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBg,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text('#$t',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary)),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // 오늘의 메뉴 추천
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('오늘의 메뉴 추천 🎰',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Text('오늘의 추천',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('내 태그 기반',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text('☀️',
                                          style: TextStyle(fontSize: 20)),
                                      const SizedBox(height: 4),
                                      const Text('점심',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary)),
                                      const SizedBox(height: 4),
                                      Text(tags.isNotEmpty ? tags.first : '파스타',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text('🌙',
                                          style: TextStyle(fontSize: 20)),
                                      const SizedBox(height: 4),
                                      const Text('저녁',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary)),
                                      const SizedBox(height: 4),
                                      Text(tags.length > 1 ? tags[1] : '삼겹살',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // 로그아웃
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: const Text('로그아웃',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        content: const Text('정말 로그아웃 하시겠어요?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('취소')),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('로그아웃',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      await SupabaseService.signOut();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (_) => false,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.bgGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('로그아웃',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.red)),
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}
