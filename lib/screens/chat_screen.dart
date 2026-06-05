// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'settlement_screen.dart';

class ChatScreen extends StatefulWidget {
  final MeetingModel meeting;

  const ChatScreen({super.key, required this.meeting});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _MemberInfo {
  final String userId;
  final String name;
  final String? avatarUrl;
  bool selected;

  _MemberInfo({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.selected = true,
  });
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _sending = false;
  List<_MemberInfo> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeRealtime();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final data = await SupabaseService.getMeetingMembers(widget.meeting.id);
      final members = data.map((member) {
        final user = member['users'] as Map<String, dynamic>?;
        final uid = member['user_id'] as String? ?? '';
        final nickname = user?['nickname'] as String?;
        final name = nickname?.isNotEmpty == true
            ? nickname!
            : (user?['name'] as String?) ?? '멤버';
        final avatar = user?['avatar_url'] as String?;
        return _MemberInfo(
          userId: uid,
          name: name,
          avatarUrl: avatar,
          selected: true,
        );
      }).toList();
      if (mounted) setState(() => _members = members);
    } catch (e) {
      debugPrint('[ChatScreen] _loadMembers error: $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await SupabaseService.getMessages(widget.meeting.id);
      setState(() {
        _messages
          ..clear()
          ..addAll(msgs);
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    _channel = SupabaseService.subscribeMessages(widget.meeting.id, (message) {
      if (_messages.any((m) => m.id == message.id)) return;
      setState(() => _messages.add(message));
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage({String? text, String type = 'text'}) async {
    final messageText = (text ?? _controller.text).trim();
    if (messageText.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      if (type == 'text') _controller.clear();
    });

    try {
      await SupabaseService.sendMessage(
        meetingId: widget.meeting.id,
        text: messageText,
        type: type,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전송 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showDutchPayDialog() {
    final totalController = TextEditingController();
    final bankController = TextEditingController();
    final dialogMembers = _members.isEmpty
        ? [
            _MemberInfo(
              userId: SupabaseService.userId,
              name: currentUser?.displayName ?? '나',
            )
          ]
        : _members
            .map(
              (member) => _MemberInfo(
                userId: member.userId,
                name: member.name,
                avatarUrl: member.avatarUrl,
              ),
            )
            .toList();

    const avatarColors = [
      Colors.black87,
      Color(0xFF7B52AB),
      Color(0xFFFFB347),
      Color(0xFF4CAF50),
      Color(0xFF2196F3),
      AppColors.primary,
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          final total =
              int.tryParse(totalController.text.replaceAll(',', '')) ?? 0;
          final selectedMembers =
              dialogMembers.where((member) => member.selected).toList();
          final count = selectedMembers.length;
          final perPerson = count > 0 ? (total / count).round() : 0;

          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '더치페이 정산',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '총 금액',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: totalController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setModal(() {}),
                      decoration: const InputDecoration(
                        hintText: '총 결제 금액',
                        suffixText: '원',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text(
                          '정산 인원',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$count명 선택',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '정산할 멤버를 선택하거나 해제하세요',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.textLight),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: List.generate(dialogMembers.length, (i) {
                        final member = dialogMembers[i];
                        final color = avatarColors[i % avatarColors.length];
                        return GestureDetector(
                          onTap: () => setModal(
                              () => member.selected = !member.selected),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: member.selected
                                          ? color
                                          : Colors.grey[300],
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: member.selected
                                            ? color
                                            : Colors.grey[400]!,
                                        width: member.selected ? 3 : 1,
                                      ),
                                    ),
                                    child: member.avatarUrl != null
                                        ? ClipOval(
                                            child: Image.network(
                                              member.avatarUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                Icons.person_rounded,
                                                color: Colors.white,
                                                size: 26,
                                              ),
                                            ),
                                          )
                                        : const Center(
                                            child: Icon(
                                              Icons.person_rounded,
                                              color: Colors.white,
                                              size: 26,
                                            ),
                                          ),
                                  ),
                                  if (member.selected)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 52,
                                child: Text(
                                  member.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: member.selected
                                        ? AppColors.textPrimary
                                        : Colors.grey[400],
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '계좌번호',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bankController,
                      onChanged: (_) => setModal(() {}),
                      decoration: const InputDecoration(
                        hintText: '예: 카카오뱅크 3333-00-0000000 홍길동',
                        prefixIcon: Icon(
                          Icons.account_balance_outlined,
                          size: 18,
                          color: AppColors.textLight,
                        ),
                      ),
                    ),
                    if (total > 0 && count > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$count명이 나눠내요',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatWon(perPerson)}원',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '총 ${_formatWon(total)}원',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: total > 0 && count > 0
                            ? () async {
                                Navigator.pop(ctx);
                                await _createAndShareSettlement(
                                  totalAmount: total,
                                  perPersonAmount: perPerson,
                                  bankInfo: bankController.text.trim(),
                                  members: selectedMembers,
                                );
                              }
                            : null,
                        child: const Text('채팅방에 공유하기'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createAndShareSettlement({
    required int totalAmount,
    required int perPersonAmount,
    required String bankInfo,
    required List<_MemberInfo> members,
  }) async {
    if (_sending) return;
    setState(() => _sending = true);

    try {
      final settlementId = await SupabaseService.createSettlement(
        meetingId: widget.meeting.id,
        totalAmount: totalAmount,
        perPersonAmount: perPersonAmount,
        bankInfo: bankInfo,
        members: members
            .map(
              (member) => {
                'user_id': member.userId,
                'user_name': member.name,
                'amount': perPersonAmount,
              },
            )
            .toList(),
      );
      final memberNames = members.map((member) => member.name).join(', ');
      final message = [
        'settlement_id:$settlementId',
        '더치페이 정산',
        '총 금액: ${_formatWon(totalAmount)}원',
        '1인당: ${_formatWon(perPersonAmount)}원',
        '정산 멤버: $memberNames',
        if (bankInfo.isNotEmpty) '입금 계좌: $bankInfo',
      ].join('\n');

      await SupabaseService.sendMessage(
        meetingId: widget.meeting.id,
        text: message,
        type: 'dutchPay',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('정산 공유 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '모임 채팅',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _messages.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 42,
                              color: AppColors.textLight,
                            ),
                            SizedBox(height: 12),
                            Text(
                              '첫 메시지를 보내보세요',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _MessageBubble(
                          message: _messages[i],
                          meeting: widget.meeting,
                        ),
                      ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              top: 8,
            ),
            color: Colors.white,
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showDutchPayDialog,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.tagBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '모임 멤버들과 이야기해보세요',
                      hintStyle: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 14,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      fillColor: AppColors.bg,
                      filled: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : () => _sendMessage(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _sending ? AppColors.textLight : AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _sending
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final MeetingModel meeting;

  const _MessageBubble({required this.message, required this.meeting});

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    if (message.type == MessageType.dutchPay) {
      return _SettlementMessageCard(message: message, meeting: meeting);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!message.isMe)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 3),
                child: Text(
                  message.senderName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: message.isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (message.isMe) ...[
                  Text(
                    _timeStr(message.time),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textLight),
                  ),
                  const SizedBox(width: 4),
                ],
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.65,
                  ),
                  decoration: BoxDecoration(
                    color: message.isMe ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(message.isMe ? 16 : 4),
                      bottomRight: Radius.circular(message.isMe ? 4 : 16),
                    ),
                    border: message.isMe
                        ? null
                        : Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          message.isMe ? Colors.white : AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                if (!message.isMe) ...[
                  const SizedBox(width: 4),
                  Text(
                    _timeStr(message.time),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textLight),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeStr(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? '오전' : '오후';
    return '$ampm $hour:$minute';
  }
}

class _SettlementMessageCard extends StatelessWidget {
  final ChatMessage message;
  final MeetingModel meeting;

  const _SettlementMessageCard({
    required this.message,
    required this.meeting,
  });

  @override
  Widget build(BuildContext context) {
    final data = _SettlementMessageData.parse(message.text);
    final isHost = meeting.hostId == SupabaseService.userId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.receipt_long_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '정산 요청이 도착했어요',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '1인당 정산 비용',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.perPersonLabel,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '총 비용: ${data.totalLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (data.memberNames.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '멤버: ${data.memberNames.join(', ')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SettlementScreen(
                                  meeting: meeting,
                                  isHost: isHost,
                                  settlementId: data.settlementId,
                                  totalAmount: data.totalAmount,
                                  bankInfo: data.bankInfo,
                                  memberNames: data.memberNames,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          child: const Text(
                            '정산 확인하기',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementMessageData {
  final String? settlementId;
  final int totalAmount;
  final String totalLabel;
  final String perPersonLabel;
  final String bankInfo;
  final List<String> memberNames;

  const _SettlementMessageData({
    required this.settlementId,
    required this.totalAmount,
    required this.totalLabel,
    required this.perPersonLabel,
    required this.bankInfo,
    required this.memberNames,
  });

  static _SettlementMessageData parse(String text) {
    String? settlementId;
    var totalAmount = 0;
    var totalLabel = '0원';
    var perPersonLabel = '0원';
    var bankInfo = '';
    var memberNames = <String>[];

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.startsWith('settlement_id:')) {
        settlementId = line.replaceFirst('settlement_id:', '').trim();
      } else if (line.startsWith('총 금액:')) {
        totalLabel = line.replaceFirst('총 금액:', '').trim();
        totalAmount = _parseWon(totalLabel);
      } else if (line.startsWith('1인당:')) {
        perPersonLabel = line.replaceFirst('1인당:', '').trim();
      } else if (line.startsWith('입금 계좌:')) {
        bankInfo = line.replaceFirst('입금 계좌:', '').trim();
      } else if (line.startsWith('정산 멤버:')) {
        memberNames = line
            .replaceFirst('정산 멤버:', '')
            .split(',')
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .toList();
      }
    }

    return _SettlementMessageData(
      settlementId: settlementId,
      totalAmount: totalAmount,
      totalLabel: totalLabel,
      perPersonLabel: perPersonLabel,
      bankInfo: bankInfo,
      memberNames: memberNames,
    );
  }

  static int _parseWon(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }
}
