// lib/screens/settlement_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class SettlementScreen extends StatefulWidget {
  final MeetingModel meeting;
  final bool isHost;
  final String? settlementId;
  final int totalAmount;
  final String bankInfo;
  final List<String> memberNames;

  const SettlementScreen({
    super.key,
    required this.meeting,
    required this.isHost,
    this.settlementId,
    this.totalAmount = 0,
    this.bankInfo = '',
    this.memberNames = const [],
  });

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  bool _loading = false;
  bool _showDetail = false;
  bool _editingBank = false;
  late TextEditingController _bankController;
  late String _bankInfo;
  late List<_Member> _members;
  int _totalAmount = 0;
  int _perPersonAmount = 0;
  DateTime? _createdAt;

  static const _colors = [
    Colors.black87,
    Color(0xFF7B52AB),
    Color(0xFFFFB347),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    AppColors.primary,
  ];

  @override
  void initState() {
    super.initState();
    _bankInfo = widget.bankInfo;
    _bankController = TextEditingController(text: _bankInfo);
    _members = [];
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _loadFallbackData();
    if (widget.settlementId == null) return;

    setState(() => _loading = true);
    try {
      final settlement =
          await SupabaseService.getSettlement(widget.settlementId!);
      final members =
          await SupabaseService.getSettlementMembers(widget.settlementId!);
      if (settlement == null) return;

      final total = settlement['total_amount'] as int? ?? 0;
      final perPerson = settlement['per_person_amount'] as int? ??
          (members.isEmpty ? 0 : (total / members.length).round());
      final bank = settlement['bank_info'] as String? ?? '';
      final createdAtText = settlement['created_at'] as String?;

      setState(() {
        _totalAmount = total;
        _perPersonAmount = perPerson;
        _bankInfo = bank;
        _bankController.text = bank;
        _createdAt =
            createdAtText == null ? null : DateTime.tryParse(createdAtText);
        _members = members.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return _Member(
            userId: row['user_id'] as String? ?? '',
            name: row['user_name'] as String? ?? '멤버',
            amount: row['amount'] as int? ?? perPerson,
            status: _PayStatus.fromDb(row['status'] as String?),
            color: _colors[i % _colors.length],
          );
        }).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('정산 정보를 불러오지 못했어요: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadFallbackData() {
    final names = widget.memberNames.isNotEmpty ? widget.memberNames : ['멤버'];
    final total = widget.totalAmount;
    final perPerson = names.isEmpty ? 0 : (total / names.length).round();

    _totalAmount = total;
    _perPersonAmount = perPerson;
    _members = List.generate(
      names.length,
      (i) => _Member(
        userId: '',
        name: names[i].trim().isEmpty ? '멤버' : names[i].trim(),
        amount: perPerson,
        status: _PayStatus.requested,
        color: _colors[i % _colors.length],
      ),
    );
  }

  Future<void> _handleStatusTap(int index) async {
    final member = _members[index];
    final settlementId = widget.settlementId;
    final isMine = member.userId == SupabaseService.userId;

    if (settlementId == null || member.userId.isEmpty) {
      if (!widget.isHost) return;
      setState(() {
        _members[index] = member.copyWith(status: _PayStatus.confirmed);
      });
      return;
    }

    final nextStatus = widget.isHost
        ? _PayStatus.confirmed
        : isMine && member.status == _PayStatus.requested
            ? _PayStatus.paid
            : null;
    if (nextStatus == null || member.status == _PayStatus.confirmed) return;

    try {
      await SupabaseService.updateSettlementMemberStatus(
        settlementId: settlementId,
        memberUserId: member.userId,
        status: nextStatus.dbValue,
      );
      await SupabaseService.syncSettlementStatus(settlementId);
      setState(() {
        _members[index] = member.copyWith(status: nextStatus);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('정산 상태를 변경하지 못했어요: $e')),
        );
      }
    }
  }

  String get _createdAtLabel {
    final dt = _createdAt?.toLocal();
    if (dt == null) return '-';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _bankController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('정산 확인'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 24),
                  RichText(
                    text: const TextSpan(
                      style:
                          TextStyle(fontSize: 16, color: AppColors.textPrimary),
                      children: [
                        TextSpan(text: '비용 청구 멤버 '),
                        TextSpan(
                          text: '상태',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isHost
                        ? '입금이 확인되면 멤버 상태를 눌러 확인 완료로 바꿀 수 있어요.'
                        : '내 이름의 상태를 누르면 입금 완료로 표시돼요.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._members.asMap().entries.map((entry) {
                    final i = entry.key;
                    final member = entry.value;
                    return _MemberRow(
                      member: member,
                      isHost: widget.isHost,
                      isMine: member.userId == SupabaseService.userId,
                      onTap: () => _handleStatusTap(i),
                    );
                  }),
                  const SizedBox(height: 32),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: const Text(
                '확인',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '정산 금액을 확인하세요',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showDetail = !_showDetail),
                child: Row(
                  children: [
                    const Text(
                      '요약보기',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    Icon(
                      _showDetail
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatWon(_totalAmount)}원',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '1인당 ${_formatWon(_perPersonAmount)}원',
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          _buildBankRow(),
          if (_showDetail) ...[
            const SizedBox(height: 12),
            Container(height: 0.5, color: Colors.white38),
            const SizedBox(height: 12),
            _DetailRow('요청 일자', _createdAtLabel),
            _DetailRow('청구 멤버', '${_members.length}명'),
            _DetailRow('총 비용', '${_formatWon(_totalAmount)}원'),
            _DetailRow(
              '모임 장소',
              widget.meeting.location.isEmpty ? '-' : widget.meeting.location,
            ),
            const _DetailRow('청구 방법', '1/N 계좌이체'),
          ],
        ],
      ),
    );
  }

  Widget _buildBankRow() {
    if (_editingBank) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _bankController,
              style: const TextStyle(fontSize: 13, color: Colors.white),
              decoration: const InputDecoration(
                hintText: '은행명 계좌번호 예금주',
                hintStyle: TextStyle(color: Colors.white54, fontSize: 12),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              autofocus: true,
            ),
          ),
          _SmallWhiteButton(
            label: '저장',
            onTap: () => setState(() {
              _bankInfo = _bankController.text.trim();
              _editingBank = false;
            }),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _editingBank = true;
              _bankController.text = _bankInfo;
            }),
            child: Text(
              _bankInfo.isEmpty ? '+ 계좌번호 입력' : _bankInfo,
              style: TextStyle(
                fontSize: 13,
                color: _bankInfo.isEmpty ? Colors.white54 : Colors.white70,
                decoration: _bankInfo.isEmpty ? TextDecoration.underline : null,
              ),
            ),
          ),
        ),
        if (_bankInfo.isNotEmpty)
          _SmallWhiteButton(
            label: '복사',
            onTap: () {
              Clipboard.setData(ClipboardData(text: _bankInfo));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('계좌번호가 복사되었어요'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
      ],
    );
  }

  static String _formatWon(int amount) {
    final text = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
      buffer.write(text[i]);
    }
    return buffer.toString();
  }
}

class _MemberRow extends StatelessWidget {
  final _Member member;
  final bool isHost;
  final bool isMine;
  final VoidCallback onTap;

  const _MemberRow({
    required this.member,
    required this.isHost,
    required this.isMine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(color: member.color, shape: BoxShape.circle),
            child: const Center(
              child: Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isMine ? '${member.name} (나)' : member.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${_SettlementScreenState._formatWon(member.amount)}원',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: member.status == _PayStatus.confirmed ? null : onTap,
            child: _StatusBadge(
              status: member.status,
              isHost: isHost,
              isMine: isMine,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ],
        ),
      );
}

class _SmallWhiteButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SmallWhiteButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

enum _PayStatus {
  requested('requested'),
  paid('paid'),
  confirmed('confirmed');

  final String dbValue;

  const _PayStatus(this.dbValue);

  static _PayStatus fromDb(String? value) {
    return switch (value) {
      'paid' => _PayStatus.paid,
      'confirmed' => _PayStatus.confirmed,
      _ => _PayStatus.requested,
    };
  }
}

class _Member {
  final String userId;
  final String name;
  final int amount;
  final _PayStatus status;
  final Color color;

  const _Member({
    required this.userId,
    required this.name,
    required this.amount,
    required this.status,
    required this.color,
  });

  _Member copyWith({_PayStatus? status}) {
    return _Member(
      userId: userId,
      name: name,
      amount: amount,
      status: status ?? this.status,
      color: color,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final _PayStatus status;
  final bool isHost;
  final bool isMine;

  const _StatusBadge({
    required this.status,
    required this.isHost,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final config = switch (status) {
      _PayStatus.confirmed => const _BadgeConfig(
          label: '확인 완료',
          color: AppColors.textSecondary,
          background: AppColors.bgGray,
          border: AppColors.bgGray,
        ),
      _PayStatus.paid => _BadgeConfig(
          label: isHost ? '확인하기' : '입금 완료',
          color: AppColors.primary,
          background: AppColors.primaryBg,
          border: AppColors.primary,
        ),
      _PayStatus.requested => _BadgeConfig(
          label: isMine && !isHost ? '입금했어요' : '요청됨',
          color: AppColors.primary,
          background: AppColors.primaryBg,
          border: AppColors.primary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: config.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.border),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          fontSize: 11,
          color: config.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BadgeConfig {
  final String label;
  final Color color;
  final Color background;
  final Color border;

  const _BadgeConfig({
    required this.label,
    required this.color,
    required this.background,
    required this.border,
  });
}
