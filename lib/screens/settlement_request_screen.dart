// lib/screens/settlement_request_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class SettlementRequestResult {
  final int totalAmount;
  final int perPersonAmount;
  final String bankInfo;
  final String? receiptImageUrl;
  final List<String> memberNames;

  const SettlementRequestResult({
    required this.totalAmount,
    required this.perPersonAmount,
    required this.bankInfo,
    this.receiptImageUrl,
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
  final _bankController = TextEditingController();
  final List<_SettlementMember> _members = [];
  Uint8List? _receiptImageBytes;
  String? _receiptImageName;
  bool _loading = true;
  bool _submitting = false;

  int get _totalAmount =>
      int.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

  int get _perPersonAmount =>
      _members.isEmpty ? 0 : (_totalAmount / _members.length).round();

  bool get _canSubmit =>
      _totalAmount > 0 &&
      _bankController.text.trim().isNotEmpty &&
      _members.isNotEmpty &&
      !_submitting;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _bankController.dispose();
    super.dispose();
  }

  Future<void> _pickReceiptImage() async {
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
        _receiptImageBytes = bytes;
        _receiptImageName = picked.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이미지를 불러오지 못했어요: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    setState(() => _submitting = true);

    try {
      final receiptImageUrl = _receiptImageBytes == null
          ? null
          : await SupabaseService.uploadSettlementImage(
              _receiptImageBytes!,
              _receiptImageName ?? 'receipt.jpg',
            );
      if (!mounted) return;

      final result = SettlementRequestResult(
        totalAmount: _totalAmount,
        perPersonAmount: _perPersonAmount,
        bankInfo: _bankController.text.trim(),
        receiptImageUrl: receiptImageUrl,
        memberNames: _members.map((member) => member.name).toList(),
      );

      final shouldRequest = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _SettlementConfirmSheet(
          totalAmount: _totalAmount,
          perPersonAmount: _perPersonAmount,
          bankInfo: _bankController.text.trim(),
          receiptImageUrl: receiptImageUrl,
          members: _members,
        ),
      );

      if (!mounted || shouldRequest != true) return;
      Navigator.pop(context, result);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                        const SizedBox(height: 12),
                        _BankInfoBox(
                          controller: _bankController,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        _ReceiptImageButton(
                          imageBytes: _receiptImageBytes,
                          fileName: _receiptImageName,
                          onTap: _pickReceiptImage,
                          onRemove: () => setState(() {
                            _receiptImageBytes = null;
                            _receiptImageName = null;
                          }),
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

class _ReceiptImageButton extends StatelessWidget {
  final Uint8List? imageBytes;
  final String? fileName;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ReceiptImageButton({
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

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt_rounded,
                    size: 22, color: Color(0xFF7C7C7C)),
                SizedBox(width: 8),
                Text(
                  '이미지 첨부하기',
                  style: TextStyle(fontSize: 14, color: Color(0xFF7C7C7C)),
                ),
              ],
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
    final hasAmount = totalAmount > 0;

    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Stack(
        children: [
          Positioned(
            left: hasAmount ? 56 : 22,
            right: hasAmount ? 14 : 22,
            top: hasAmount ? 38 : 0,
            bottom: hasAmount ? 9 : 0,
            child: Center(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                onChanged: onChanged,
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(
                  fontSize: hasAmount ? 28 : 18,
                  height: 1,
                  fontWeight: hasAmount ? FontWeight.w900 : FontWeight.w500,
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: hasAmount ? null : '얼마를 정산할까요?',
                  hintStyle: const TextStyle(
                    fontSize: 18,
                    height: 1,
                    color: Color(0xFF7C7C7C),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  suffixText: hasAmount ? '원' : null,
                  suffixStyle: const TextStyle(
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          if (hasAmount)
            const Positioned(
              left: 18,
              top: 10,
              child: Text(
                '얼마를 정산할까요?',
                style: TextStyle(fontSize: 13, color: Color(0xFF7C7C7C)),
              ),
            ),
          if (hasAmount)
            Positioned(
              left: 18,
              top: 44,
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '₩',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
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

class _BankInfoBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _BankInfoBox({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 18),
          const Icon(
            Icons.account_balance_rounded,
            size: 22,
            color: Color(0xFF7C7C7C),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              onChanged: onChanged,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
              decoration: const InputDecoration(
                hintText: '은행/계좌번호를 입력해주세요',
                hintStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9A9A9A),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 18),
        ],
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
  final String bankInfo;
  final String? receiptImageUrl;
  final List<_SettlementMember> members;

  const _SettlementConfirmSheet({
    required this.totalAmount,
    required this.perPersonAmount,
    required this.bankInfo,
    required this.receiptImageUrl,
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
                  const SizedBox(height: 10),
                  Text(
                    bankInfo,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7C7C7C),
                    ),
                  ),
                  if (receiptImageUrl != null) ...[
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_camera_rounded,
                            size: 15, color: Color(0xFF7C7C7C)),
                        SizedBox(width: 4),
                        Text('첨부 이미지 포함',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF7C7C7C))),
                      ],
                    ),
                  ],
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
