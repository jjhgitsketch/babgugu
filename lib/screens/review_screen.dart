// lib/screens/review_screen.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class ReviewScreen extends StatefulWidget {
  final MeetingModel meeting;
  const ReviewScreen({super.key, required this.meeting});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  // 임시 멤버 + 색상
  final List<_ReviewMember> _members = [
    _ReviewMember(name: '멤버1', color: const Color(0xFF7B52AB), rating: 0),
    _ReviewMember(name: '멤버2', color: const Color(0xFFFFB347), rating: 0),
    _ReviewMember(name: '모임장', color: AppColors.primary, rating: 0),
  ];

  void _setRating(int memberIdx, int rating) {
    setState(() => _members[memberIdx] = _ReviewMember(
      name: _members[memberIdx].name,
      color: _members[memberIdx].color,
      rating: rating,
    ));
  }

  Future<void> _submit() async {
    // TODO: 평가 저장 API
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('평가하기'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const Text(
              '오늘의 모임의 멤버는 어떠셨나요?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              '스티커를 눌러 평가해주세요',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),

            // 멤버 평가
            Expanded(
              child: ListView.separated(
                itemCount: _members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 24),
                itemBuilder: (_, i) => Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(color: _members[i].color, shape: BoxShape.circle),
                      child: const Center(child: Icon(Icons.person_rounded, color: Colors.white, size: 24)),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_members[i].name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Row(
                          children: List.generate(5, (starIdx) => GestureDetector(
                            onTap: () => _setRating(i, starIdx + 1),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                starIdx < _members[i].rating
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: starIdx < _members[i].rating
                                    ? AppColors.primary
                                    : AppColors.divider,
                                size: 28,
                              ),
                            ),
                          )),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 하단 버튼
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBg,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Center(
                        child: Text('건너뛰기',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: const Text('확인', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ReviewMember {
  final String name;
  final Color color;
  final int rating;
  const _ReviewMember({required this.name, required this.color, required this.rating});
}
