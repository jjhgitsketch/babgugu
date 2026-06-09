// lib/screens/settlement_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'review_screen.dart';

class SettlementScreen extends StatefulWidget {
  final MeetingModel meeting;
  final bool isHost;
  final int totalAmount;
  final String bankInfo;
  final List<String> memberNames;

  const SettlementScreen({
    super.key,
    required this.meeting,
    required this.isHost,
    this.totalAmount = 0,
    this.bankInfo = '신한은행 1000-000-000001',
    this.memberNames = const [],
  });

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  late final List<_SettlementMember> _members;
  late final DateTime _requestedAt;
  bool _showSummary = true;

  int get _memberCount => _members.isEmpty ? 1 : _members.length;
  int get _totalAmount => widget.totalAmount > 0 ? widget.totalAmount : 0;
  bool get _allPaid =>
      _members.every((member) => member.status == _PayStatus.done);

  @override
  void initState() {
    super.initState();
    _requestedAt = DateTime.now();
    final fallbackName = currentUser?.name ?? '모임 멤버';
    final names = widget.memberNames.isEmpty
        ? <String>[fallbackName]
        : widget.memberNames;
    final perPersonAmount =
        names.isEmpty ? 0 : (_totalAmount / names.length).round();
    _members = names
        .map((name) => _SettlementMember(
              name: name.trim().isEmpty ? '모임 멤버' : name.trim(),
              amount: perPersonAmount,
              status: _PayStatus.pending,
            ))
        .toList();
  }

  void _confirmPayment(int index) {
    if (!widget.isHost) return;
    setState(() {
      _members[index] = _members[index].copyWith(status: _PayStatus.done);
    });
  }

  bool _isCurrentUserMember(_SettlementMember member) {
    final memberName = member.name.trim();
    if (memberName.isEmpty) return false;

    final userNames = <String?>[
      currentUser?.name,
      currentUser?.nickname,
      currentUser?.displayName,
    ]
        .where((name) => name != null && name.trim().isNotEmpty)
        .map((name) => name!.trim())
        .toSet();

    return userNames.contains(memberName);
  }

  Future<void> _requestPaymentCheck(int index) async {
    if (widget.isHost) return;
    final member = _members[index];
    if (!_isCurrentUserMember(member)) {
      _showSnackBar('본인 입금만 확인 요청할 수 있어요.');
      return;
    }
    if (member.status != _PayStatus.pending) return;

    setState(() {
      _members[index] = member.copyWith(status: _PayStatus.requested);
    });

    try {
      await SupabaseService.sendMessage(
        meetingId: widget.meeting.id,
        text: '입금 확인 요청\nmember:${currentUser?.name ?? member.name}',
        type: 'paymentConfirmRequest',
      );
      _showSnackBar('모임장에게 입금 확인 요청을 보냈어요.');
    } catch (e) {
      setState(() {
        _members[index] = member;
      });
      _showSnackBar('요청을 보내지 못했어요: $e');
    }
  }

  void _copyBankInfo() {
    Clipboard.setData(ClipboardData(text: widget.bankInfo));
    _showSnackBar('계좌번호가 복사되었어요.');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _finishSettlement() async {
    final reviewed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewScreen(meeting: widget.meeting),
        fullscreenDialog: true,
      ),
    );
    if (!mounted) return;
    Navigator.pop(context, reviewed == true);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = screenWidth.clamp(0, 360).toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          '정산 확인',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFDADADA)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 26, 16, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SettlementSummaryCard(
                          totalAmount: _totalAmount,
                          memberCount: _memberCount,
                          requestedAt: _requestedAt,
                          bankInfo: widget.bankInfo,
                          meeting: widget.meeting,
                          requesterName: widget.isHost
                              ? (currentUser?.name ?? '모임장')
                              : '모임장',
                          showSummary: _showSummary,
                          onToggleSummary: () {
                            setState(() => _showSummary = !_showSummary);
                          },
                          onCopyBankInfo: _copyBankInfo,
                        ),
                        const SizedBox(height: 25),
                        _RequesterTitle(
                          name: widget.isHost
                              ? (currentUser?.name ?? widget.meeting.hostName)
                              : widget.meeting.hostName.isEmpty
                                  ? '모임장'
                                  : widget.meeting.hostName,
                        ),
                        const SizedBox(height: 25),
                        for (var i = 0; i < _members.length; i++)
                          _SettlementMemberRow(
                            member: _members[i],
                            isHost: widget.isHost,
                            enabled: widget.isHost ||
                                _isCurrentUserMember(_members[i]),
                            onPressed: widget.isHost
                                ? () => _confirmPayment(i)
                                : () => _requestPaymentCheck(i),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _BottomConfirmButton(
              enabled: widget.isHost ? _allPaid : true,
              onPressed: _finishSettlement,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettlementSummaryCard extends StatelessWidget {
  final int totalAmount;
  final int memberCount;
  final DateTime requestedAt;
  final String bankInfo;
  final MeetingModel meeting;
  final String requesterName;
  final bool showSummary;
  final VoidCallback onToggleSummary;
  final VoidCallback onCopyBankInfo;

  const _SettlementSummaryCard({
    required this.totalAmount,
    required this.memberCount,
    required this.requestedAt,
    required this.bankInfo,
    required this.meeting,
    required this.requesterName,
    required this.showSummary,
    required this.onToggleSummary,
    required this.onCopyBankInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 250),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 15),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '정산 금액을 확인하세요',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
              InkWell(
                onTap: onToggleSummary,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    showSummary ? '요약닫기⌃' : '요약보기⌄',
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '${_formatWon(totalAmount)}원',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  bankInfo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 18,
                child: ElevatedButton(
                  onPressed: onCopyBankInfo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF0EF),
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    '계좌번호 복사',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          if (showSummary) ...[
            const SizedBox(height: 20),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.8)),
            const SizedBox(height: 10),
            _SummaryRow(label: '요청 일자', value: _formatDateTime(requestedAt)),
            _SummaryRow(label: '청구 멤버', value: requesterName),
            _SummaryRow(
              label: '총 비용',
              value: '총 ${_formatWon(totalAmount)}원 / $memberCount명',
            ),
            _SummaryRow(
              label: '모임 장소명',
              value: meeting.location.isEmpty ? '식당 이름 어디점' : meeting.location,
            ),
            const SizedBox(height: 4),
            const Row(
              children: [
                Icon(Icons.photo_camera_rounded, size: 15, color: Colors.white),
                SizedBox(width: 3),
                Text(
                  '첨부한 이미지 보기',
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequesterTitle extends StatelessWidget {
  final String name;

  const _RequesterTitle({required this.name});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 18, color: Colors.black),
        children: [
          const TextSpan(text: '비용 청구자  '),
          TextSpan(
            text: name.isEmpty ? '모임장' : name,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SettlementMemberRow extends StatelessWidget {
  final _SettlementMember member;
  final bool isHost;
  final bool enabled;
  final VoidCallback onPressed;

  const _SettlementMemberRow({
    required this.member,
    required this.isHost,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = member.status == _PayStatus.done;
    final isRequested = member.status == _PayStatus.requested;
    final buttonLabel = isHost
        ? isDone
            ? '입금 완료'
            : '입금 확인'
        : isDone
            ? '입금 완료'
            : isRequested
                ? '요청 완료'
                : '입금 확인 요청';
    final buttonWidth = isHost ? 70.0 : 104.0;
    final isDisabled = !enabled || isDone || isRequested && !isHost;

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          _MemberAvatar(name: member.name),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          _UnderlinedAmount(amount: member.amount),
          const SizedBox(width: 8),
          SizedBox(
            width: buttonWidth,
            height: 30,
            child: ElevatedButton(
              onPressed: isDisabled ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDisabled ? const Color(0xFFD9D9D9) : AppColors.primary,
                disabledBackgroundColor: const Color(0xFFD9D9D9),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  buttonLabel,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _MemberAvatar extends StatelessWidget {
  final String name;

  const _MemberAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EF),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD9D9D9), width: 0.9),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '밥' : name.substring(0, 1),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _UnderlinedAmount extends StatelessWidget {
  final int amount;

  const _UnderlinedAmount({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_formatWon(amount)} 원',
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Container(width: 37, height: 1, color: Colors.black),
      ],
    );
  }
}

class _BottomConfirmButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _BottomConfirmButton({
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 10, 25, 12),
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: enabled ? onPressed : null,
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
            child: const Text(
              '확인',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}

enum _PayStatus { pending, requested, done }

class _SettlementMember {
  final String name;
  final int amount;
  final _PayStatus status;

  const _SettlementMember({
    required this.name,
    required this.amount,
    required this.status,
  });

  _SettlementMember copyWith({_PayStatus? status}) {
    return _SettlementMember(
      name: name,
      amount: amount,
      status: status ?? this.status,
    );
  }
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

String _formatDateTime(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)}  '
      '${two(time.hour)}:${two(time.minute)}';
}
