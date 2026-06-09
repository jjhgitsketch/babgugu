// lib/screens/review_screen.dart
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class ReviewScreen extends StatefulWidget {
  final MeetingModel meeting;

  const ReviewScreen({super.key, required this.meeting});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final List<_ReviewMember> _members = [];
  bool _loading = true;
  bool _saving = false;

  bool get _canSubmit =>
      !_saving && _members.any((member) => member.rating > 0);

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final rows = await SupabaseService.getMeetingMembers(widget.meeting.id);
      final members = <_ReviewMember>[];
      final seenUserIds = <String>{};

      for (final row in rows) {
        final userId = (row['user_id'] ?? '').toString();
        if (userId.isEmpty || userId == SupabaseService.userId) continue;
        if (!seenUserIds.add(userId)) continue;

        final user = row['users'] as Map<String, dynamic>?;
        final nickname = (user?['nickname'] ?? '').toString().trim();
        final name = nickname.isNotEmpty
            ? nickname
            : (user?['name'] ?? '모임 멤버').toString();
        members.add(
          _ReviewMember(
            userId: userId,
            name: name.trim().isEmpty ? '모임 멤버' : name.trim(),
            avatarUrl: user?['avatar_url'] as String?,
          ),
        );
      }

      if (widget.meeting.hostId.isNotEmpty &&
          widget.meeting.hostId != SupabaseService.userId &&
          !seenUserIds.contains(widget.meeting.hostId)) {
        members.insert(
          0,
          _ReviewMember(
            userId: widget.meeting.hostId,
            name: widget.meeting.hostName.isEmpty
                ? '모임장'
                : widget.meeting.hostName,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _members
          ..clear()
          ..addAll(members);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnackBar('평가 멤버를 불러오지 못했어요: $e');
    }
  }

  void _setRating(int index, int rating) {
    setState(() => _members[index] = _members[index].copyWith(rating: rating));
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() => _saving = true);
    try {
      final ratedMembers = _members.where((member) => member.rating > 0);
      await Future.wait(
        ratedMembers.map(
          (member) => SupabaseService.submitTrustReview(
            meetingId: widget.meeting.id,
            reviewedUserId: member.userId,
            score: member.rating.toDouble(),
          ),
        ),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnackBar('평가 저장에 실패했어요: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = screenWidth.clamp(0, 393).toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _ReviewHeader(),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: contentWidth),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(25, 65, 25, 24),
                          children: [
                            const Text(
                              '오늘의 모임은 어떠셨나요?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              '스티커를 눌러 평가해주세요',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8F8F8F),
                              ),
                            ),
                            const SizedBox(height: 64),
                            if (_members.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 30),
                                child: Text(
                                  '평가할 수 있는 다른 멤버가 없어요',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                            else
                              ...List.generate(
                                _members.length,
                                (index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 18),
                                  child: _ReviewMemberRow(
                                    member: _members[index],
                                    onRatingSelected: (rating) =>
                                        _setRating(index, rating),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(25, 10, 25, 20),
                child: SizedBox(
                  width: double.infinity,
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '확인',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
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

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFDADADA), width: 1),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 13),
          IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 21),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '평가하기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 61),
        ],
      ),
    );
  }
}

class _ReviewMemberRow extends StatelessWidget {
  final _ReviewMember member;
  final ValueChanged<int> onRatingSelected;

  const _ReviewMemberRow({
    required this.member,
    required this.onRatingSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ReviewAvatar(member: member),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: List.generate(
                  5,
                  (index) => Padding(
                    padding: EdgeInsets.only(right: index == 4 ? 0 : 9),
                    child: _RiceRatingButton(
                      selected: index < member.rating,
                      onTap: () => onRatingSelected(index + 1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewAvatar extends StatelessWidget {
  final _ReviewMember member;

  const _ReviewAvatar({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 71,
      height: 71,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD9D9D9), width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: member.avatarUrl == null
          ? Center(
              child: Text(
                member.name.isEmpty ? '밥' : member.name.substring(0, 1),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            )
          : Image.network(
              member.avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  member.name.isEmpty ? '밥' : member.name.substring(0, 1),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
    );
  }
}

class _RiceRatingButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _RiceRatingButton({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : const Color(0xFFBDBDBD);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 33,
        height: 33,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.rice_bowl_outlined, size: 31, color: color),
            if (selected)
              Positioned(
                top: 5,
                child: Icon(Icons.auto_awesome, size: 10, color: color),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewMember {
  final String userId;
  final String name;
  final String? avatarUrl;
  final int rating;

  const _ReviewMember({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.rating = 0,
  });

  _ReviewMember copyWith({int? rating}) {
    return _ReviewMember(
      userId: userId,
      name: name,
      avatarUrl: avatarUrl,
      rating: rating ?? this.rating,
    );
  }
}
