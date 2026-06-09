// lib/screens/settlement_request_screen.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class SettlementRequestResult {
  final int totalAmount;
  final int perPersonAmount;
  final List<String> memberNames;

  const SettlementRequestResult({
    required this.totalAmount,
    required this.perPersonAmount,
    required this.memberNames,
  });
}

class SettlementRequestScreen extends StatefulWidget {
  final MeetingModel meeting;

  const SettlementRequestScreen({super.key, required this.meeting});

  @override
  State<SettlementRequestScreen> createState() =>
      _SettlementRequestScreenState();
}

class _SettlementRequestScreenState extends State<SettlementRequestScreen> {
  final _amountController = TextEditingController();
  final List<_SettlementMember> _members = [];
  bool _loading = true;

  int get _totalAmount =>
      int.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

  int get _perPersonAmount =>
      _members.isEmpty ? 0 : (_totalAmount / _members.length).round();

  bool get _canSubmit => _totalAmount > 0 && _members.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final rows = await SupabaseService.getMeetingMembers(widget.meeting.id);
      final members = rows.asMap().entries.map((entry) {
        final row = entry.value;
        final user = row['users'] as Map<String, dynamic>?;
        final nickname = user?['nickname'] as String?;
        final name = nickname?.isNotEmpty == true
            ? nickname!
            : (user?['name'] as String?) ?? '멤버';
        return _SettlementMember(
          name: name,
          avatarUrl: user?['avatar_url'] as String?,
          color: _avatarColors[entry.key % _avatarColors.length],
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _members
          ..clear()
          ..addAll(members);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _removeMember(_SettlementMember member) {
    if (_members.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정산 멤버는 최소 1명 이상이어야 해요')),
      );
      return;
    }
    setState(() => _members.remove(member));
  }

  Future<void> _confirmRequest() async {
    if (!_canSubmit) return;
    final result = SettlementRequestResult(
      totalAmount: _totalAmount,
      perPersonAmount: _perPersonAmount,
      memberNames: _members.map((member) => member.name).toList(),
    );

    final shouldRequest = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SettlementConfirmSheet(
        totalAmount: _totalAmount,
        perPersonAmount: _perPersonAmount,
        members: _members,
      ),
    );

    if (!mounted || shouldRequest != true) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('정산 금액 입력'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 21),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFDADADA)),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 49, 22, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 337),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AmountBox(
                          controller: _amountController,
                          totalAmount: _totalAmount,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_alt_rounded,
                                  size: 22, color: Color(0xFF7C7C7C)),
                              SizedBox(width: 8),
                              Text(
                                '이미지 첨부하기',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF7C7C7C),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          '멤버 ${_members.length}명',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF7C7C7C),
                          ),
                        ),
                        const SizedBox(height: 21),
                        ..._members.map(
                          (member) => Padding(
                            padding: const EdgeInsets.only(bottom: 11),
                            child: _MemberAmountRow(
                              member: member,
                              amount: _perPersonAmount,
                              showRemove: _totalAmount == 0,
                              onRemove: () => _removeMember(member),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 26),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 344),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _confirmRequest : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canSubmit
                        ? AppColors.primary
                        : const Color(0xFFFFF0EF),
                    disabledBackgroundColor: const Color(0xFFFFF0EF),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountBox extends StatelessWidget {
  final TextEditingController controller;
  final int totalAmount;
  final ValueChanged<String> onChanged;

  const _AmountBox({
    required this.controller,
    required this.totalAmount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: totalAmount > 0
          ? Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 18, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '얼마를 정산할까요?',
                    style: TextStyle(fontSize: 13, color: Color(0xFF7C7C7C)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 27,
                        height: 27,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            '₩',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          onChanged: onChanged,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            suffixText: '원',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 20, color: Colors.black),
              decoration: const InputDecoration(
                hintText: '얼마를 정산할까요?',
                hintStyle: TextStyle(fontSize: 20, color: Color(0xFF7C7C7C)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 22),
              ),
            ),
    );
  }
}

class _MemberAmountRow extends StatelessWidget {
  final _SettlementMember member;
  final int amount;
  final bool showRemove;
  final VoidCallback onRemove;

  const _MemberAmountRow({
    required this.member,
    required this.amount,
    required this.showRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          _MemberAvatar(member: member, radius: 32),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              member.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (amount > 0)
            _UnderlinedAmount(amount: amount)
          else if (showRemove)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(
                Icons.cancel_rounded,
                color: Color(0xFFD9D9D9),
                size: 22,
              ),
              tooltip: '멤버 제외',
            ),
        ],
      ),
    );
  }
}

class _SettlementConfirmSheet extends StatelessWidget {
  final int totalAmount;
  final int perPersonAmount;
  final List<_SettlementMember> members;

  const _SettlementConfirmSheet({
    required this.totalAmount,
    required this.perPersonAmount,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 13),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 366),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 45,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDADADA),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Text(
                    '총 ${_formatWon(totalAmount)}원을\n정산 요청할까요?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 17),
                  ...members.map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: _ConfirmMemberRow(
                        member: member,
                        amount: perPersonAmount,
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  Row(
                    children: [
                      Expanded(
                        flex: 114,
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFF0EF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              '취소',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        flex: 185,
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              '요청하기',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmMemberRow extends StatelessWidget {
  final _SettlementMember member;
  final int amount;

  const _ConfirmMemberRow({required this.member, required this.amount});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 51,
      child: Row(
        children: [
          _MemberAvatar(member: member, radius: 25),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              member.name,
              style: const TextStyle(fontSize: 13, color: Colors.black),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _UnderlinedAmount(amount: amount, small: true),
        ],
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  final _SettlementMember member;
  final double radius;

  const _MemberAvatar({required this.member, required this.radius});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFD9D9D9),
      child: CircleAvatar(
        radius: radius - 1,
        backgroundColor: member.color,
        backgroundImage:
            member.avatarUrl == null ? null : NetworkImage(member.avatarUrl!),
        child: member.avatarUrl == null
            ? Text(
                member.name.isEmpty ? '?' : member.name.characters.first,
                style: TextStyle(
                  fontSize: radius * 0.68,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              )
            : null,
      ),
    );
  }
}

class _UnderlinedAmount extends StatelessWidget {
  final int amount;
  final bool small;

  const _UnderlinedAmount({required this.amount, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_formatWon(amount)} 원',
          style: TextStyle(
            fontSize: small ? 12 : 15,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: small ? 42 : 53,
          height: 1,
          color: const Color(0xFFDADADA),
        ),
      ],
    );
  }
}

class _SettlementMember {
  final String name;
  final String? avatarUrl;
  final Color color;

  const _SettlementMember({
    required this.name,
    required this.avatarUrl,
    required this.color,
  });
}

String _formatWon(int amount) {
  final text = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return buffer.toString();
}

const _avatarColors = [
  Colors.black87,
  Color(0xFF7B52AB),
  Color(0xFFFFB347),
  Color(0xFF4CAF50),
  Color(0xFF2196F3),
  AppColors.primary,
];
