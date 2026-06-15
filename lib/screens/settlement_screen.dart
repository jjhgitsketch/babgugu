// lib/screens/settlement_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';
import 'review_screen.dart';

class SettlementScreen extends StatefulWidget {
  final MeetingModel meeting;
  final bool isHost;
  final String? settlementId;
  final int totalAmount;
  final String bankInfo;
  final String? receiptImageUrl;
  final List<String> memberNames;

  const SettlementScreen({
    super.key,
    required this.meeting,
    required this.isHost,
    this.settlementId,
    this.totalAmount = 0,
    this.bankInfo = '\uC2E0\uD55C\uC740\uD589 1000-000-000001',
    this.receiptImageUrl,
    this.memberNames = const [],
  });

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  List<_SettlementMember> _members = [];
  DateTime _requestedAt = DateTime.now();
  String? _activeSettlementId;
  int? _savedTotalAmount;
  String? _savedBankInfo;
  String? _savedReceiptImageUrl;
  bool _showSummary = true;

  int get _memberCount => _members.isEmpty ? 1 : _members.length;
  int get _totalAmount => (_savedTotalAmount != null && _savedTotalAmount! > 0)
      ? _savedTotalAmount!
      : widget.totalAmount > 0
          ? widget.totalAmount
          : 0;
  String get _bankInfo => _savedBankInfo ?? widget.bankInfo;
  String? get _receiptImageUrl =>
      _savedReceiptImageUrl ?? widget.receiptImageUrl;

  bool get _allPaid {
    final payableMembers = _members.where((member) => !_isHostMember(member));
    if (payableMembers.isEmpty) return true;
    return payableMembers.every(
      (member) => member.status == _PayStatus.done,
    );
  }

  @override
  void initState() {
    super.initState();
    _activeSettlementId = widget.settlementId;
    _members = _buildFallbackMembers();
    _loadSettlementState();
  }

  List<_SettlementMember> _buildFallbackMembers() {
    final fallbackName = currentUser?.name ?? '\uBAA8\uC784 \uBA64\uBC84';
    final names = widget.memberNames.isEmpty
        ? <String>[fallbackName]
        : widget.memberNames;
    final perPersonAmount =
        names.isEmpty ? 0 : (_totalAmount / names.length).round();
    return names
        .map(
          (name) => _SettlementMember(
            name:
                name.trim().isEmpty ? '\uBAA8\uC784 \uBA64\uBC84' : name.trim(),
            amount: perPersonAmount,
            status: _PayStatus.pending,
          ),
        )
        .toList();
  }

  Future<void> _loadSettlementState() async {
    final state = await SupabaseService.getSettlementState(
      settlementId: widget.settlementId,
      meetingId: widget.meeting.id,
    );
    if (!mounted || state == null) return;

    final rows = List<Map<String, dynamic>>.from(
      (state['members'] as List?) ?? const [],
    );
    final members = rows.map((row) {
      return _SettlementMember(
        userId: row['user_id'] as String? ?? '',
        name: (row['user_name'] as String?)?.trim().isNotEmpty == true
            ? (row['user_name'] as String).trim()
            : '\uBAA8\uC784 \uBA64\uBC84',
        amount: (row['amount'] as num?)?.toInt() ?? 0,
        status: _PayStatusX.fromDb(row['status'] as String?),
      );
    }).toList();

    setState(() {
      _activeSettlementId = state['id'] as String?;
      _savedTotalAmount = (state['total_amount'] as num?)?.toInt();
      _savedBankInfo = state['bank_info'] as String?;
      _savedReceiptImageUrl = state['memo'] as String?;
      final createdAt = state['created_at'] as String?;
      if (createdAt != null) {
        _requestedAt = parseSupabaseServerTime(createdAt);
      }
      if (members.isNotEmpty) _members = members;
    });
  }

  Future<void> _confirmPayment(int index) async {
    if (!widget.isHost || _isHostMember(_members[index])) return;
    final member = _members[index];
    setState(() {
      _members[index] = member.copyWith(status: _PayStatus.done);
    });

    try {
      final settlementId = _activeSettlementId;
      if (settlementId != null && member.userId.isNotEmpty) {
        await SupabaseService.updateSettlementMemberStatus(
          settlementId: settlementId,
          memberUserId: member.userId,
          status: 'confirmed',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _members[index] = member);
      _showSnackBar(
          '\uC785\uAE08 \uD655\uC778\uC744 \uC800\uC7A5\uD558\uC9C0 \uBABB\uD588\uC5B4\uC694: $e');
    }
  }

  bool _isCurrentUserMember(_SettlementMember member) {
    if (member.userId.isNotEmpty && member.userId == SupabaseService.userId) {
      return true;
    }
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

  bool _isHostMember(_SettlementMember member) {
    if (member.userId.isNotEmpty && member.userId == widget.meeting.hostId) {
      return true;
    }
    final memberName = member.name.trim();
    if (memberName.isEmpty) return false;

    final hostNames = <String?>[
      widget.meeting.hostName,
      widget.isHost ? currentUser?.name : null,
      widget.isHost ? currentUser?.nickname : null,
      widget.isHost ? currentUser?.displayName : null,
    ]
        .where((name) => name != null && name.trim().isNotEmpty)
        .map((name) => name!.trim())
        .toSet();

    return hostNames.contains(memberName);
  }

  Widget _buildMemberRow(int index) {
    final member = _members[index];
    final isHostSelf = widget.isHost && _isHostMember(member);

    return _SettlementMemberRow(
      member: member,
      isHost: widget.isHost,
      isHostSelf: isHostSelf,
      enabled: isHostSelf || widget.isHost
          ? !isHostSelf
          : _isCurrentUserMember(member),
      onPressed: widget.isHost
          ? () => _confirmPayment(index)
          : () => _requestPaymentCheck(index),
    );
  }

  Future<void> _requestPaymentCheck(int index) async {
    if (widget.isHost) return;
    final member = _members[index];
    if (!_isCurrentUserMember(member)) {
      _showSnackBar(
          '\uBCF8\uC778 \uC785\uAE08\uB9CC \uD655\uC778 \uC694\uCCAD\uD560 \uC218 \uC788\uC5B4\uC694.');
      return;
    }
    if (member.status != _PayStatus.pending) return;

    setState(() {
      _members[index] = member.copyWith(status: _PayStatus.requested);
    });

    try {
      final settlementId = _activeSettlementId;
      if (settlementId != null && member.userId.isNotEmpty) {
        await SupabaseService.updateSettlementMemberStatus(
          settlementId: settlementId,
          memberUserId: member.userId,
          status: 'paid',
        );
      }
      await SupabaseService.sendMessage(
        meetingId: widget.meeting.id,
        text:
            '\uC785\uAE08 \uD655\uC778 \uC694\uCCAD\nmember:${currentUser?.name ?? member.name}',
        type: 'paymentConfirmRequest',
      );
      _showSnackBar(
          '\uBAA8\uC784\uC7A5\uC5D0\uAC8C \uC785\uAE08 \uD655\uC778 \uC694\uCCAD\uC744 \uBCF4\uB0C8\uC5B4\uC694.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _members[index] = member;
      });
      _showSnackBar(
          '\uC694\uCCAD\uC744 \uBCF4\uB0B4\uC9C0 \uBABB\uD588\uC5B4\uC694: $e');
    }
  }

  void _copyBankInfo() {
    Clipboard.setData(ClipboardData(text: _bankInfo));
    _showSnackBar(
        '\uACC4\uC88C\uBC88\uD638\uAC00 \uBCF5\uC0AC\uB418\uC5C8\uC5B4\uC694.');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _finishSettlement() async {
    final alreadyReviewed =
        await SupabaseService.hasSubmittedTrustReview(widget.meeting.id);
    if (!mounted) return;

    final reviewed = alreadyReviewed
        ? true
        : await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => ReviewScreen(meeting: widget.meeting),
              fullscreenDialog: true,
            ),
          );
    if (!mounted) return;
    if (reviewed == true && _activeSettlementId != null) {
      await SupabaseService.completeSettlement(_activeSettlementId!);
    }
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
                          bankInfo: _bankInfo,
                          receiptImageUrl: _receiptImageUrl,
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
                          _buildMemberRow(i),
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
  final String? receiptImageUrl;
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
    required this.receiptImageUrl,
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
            _SummaryRow(
                label: '\uC694\uCCAD \uC77C\uC790',
                value: _formatDateTime(requestedAt)),
            _SummaryRow(
                label: '\uCCAD\uAD6C \uBA64\uBC84', value: requesterName),
            _SummaryRow(
              label: '\uCD1D \uBE44\uC6A9',
              value:
                  '\uCD1D ${_formatWon(totalAmount)}\uC6D0 / $memberCount\uBA85',
            ),
            _SummaryRow(
              label: '\uBAA8\uC784 \uC7A5\uC18C\uBA85',
              value: meeting.location.isEmpty
                  ? '\uC2DD\uB2F9 \uC774\uB984 \uC5B4\uB514\uC810'
                  : meeting.location,
            ),
            const SizedBox(height: 4),
            if (receiptImageUrl == null || receiptImageUrl!.trim().isEmpty)
              const Row(
                children: [
                  Icon(Icons.photo_camera_rounded,
                      size: 15, color: Colors.white),
                  SizedBox(width: 3),
                  Text('\uCCA8\uBD80 \uC774\uBBF8\uC9C0 \uC5C6\uC74C',
                      style: TextStyle(fontSize: 10, color: Colors.white)),
                ],
              )
            else
              _ReceiptImageButton(imageUrl: receiptImageUrl!),
          ],
        ],
      ),
    );
  }
}

class _ReceiptImageButton extends StatelessWidget {
  final String imageUrl;

  const _ReceiptImageButton({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: () => _showReceiptImage(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.image_rounded, size: 16),
        label: const Text(
          '\uC774\uBBF8\uC9C0 \uD655\uC778\uD558\uAE30',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  void _showReceiptImage(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text(
                      '\uC774\uBBF8\uC9C0\uB97C \uBD88\uB7EC\uC624\uC9C0 \uBABB\uD588\uC5B4\uC694',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
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
  final bool isHostSelf;
  final VoidCallback onPressed;

  const _SettlementMemberRow({
    required this.member,
    required this.isHost,
    required this.isHostSelf,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = member.status == _PayStatus.done;
    final isRequested = member.status == _PayStatus.requested;
    final buttonLabel = isHostSelf
        ? '\uBAA8\uC784\uC7A5'
        : isHost
            ? isDone
                ? '입금 완료'
                : '입금 확인'
            : isDone
                ? '입금 완료'
                : isRequested
                    ? '요청 완료'
                    : '입금 확인 요청';
    final buttonWidth = isHost ? 70.0 : 104.0;
    final isDisabled =
        isHostSelf || !enabled || isDone || isRequested && !isHost;

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

extension _PayStatusX on _PayStatus {
  static _PayStatus fromDb(String? status) {
    switch (status) {
      case 'paid':
        return _PayStatus.requested;
      case 'confirmed':
        return _PayStatus.done;
      case 'requested':
      default:
        return _PayStatus.pending;
    }
  }
}

class _SettlementMember {
  final String userId;
  final String name;
  final int amount;
  final _PayStatus status;

  const _SettlementMember({
    this.userId = '',
    required this.name,
    required this.amount,
    required this.status,
  });

  _SettlementMember copyWith({_PayStatus? status}) {
    return _SettlementMember(
      userId: userId,
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
