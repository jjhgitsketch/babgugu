// lib/screens/chat_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'public_profile_screen.dart';
import 'settlement_request_screen.dart';
import 'settlement_screen.dart';

class ChatScreen extends StatefulWidget {
  final MeetingModel meeting;

  const ChatScreen({super.key, required this.meeting});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await SupabaseService.getMessages(widget.meeting.id);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnackBar('채팅을 불러오지 못했어요: $e');
    }
  }

  void _subscribeRealtime() {
    _channel = SupabaseService.subscribeMessages(widget.meeting.id, (message) {
      if (!mounted || _messages.any((m) => m.id == message.id)) return;
      setState(() => _messages.add(message));
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
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
      _showSnackBar('전송에 실패했어요: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openSettlementRequest() async {
    if (widget.meeting.hostId != SupabaseService.userId) {
      _showSnackBar('모임장만 정산을 시작할 수 있어요.');
      return;
    }

    final result = await Navigator.push<SettlementRequestResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SettlementRequestScreen(meeting: widget.meeting),
        fullscreenDialog: true,
      ),
    );
    if (result == null) return;

    final bankInfo = result.bankInfo.replaceAll(RegExp(r'\s+'), ' ').trim();
    await _sendMessage(
      text: [
        'settlement_request',
        'total:${result.totalAmount}',
        'per_person:${result.perPersonAmount}',
        'bank:$bankInfo',
        'members:${result.memberNames.join(',')}',
      ].join('\n'),
      type: 'dutchPay',
    );
  }

  Future<void> _markMeetingStarted() async {
    if (widget.meeting.hostId != SupabaseService.userId) {
      _showSnackBar('모임장만 모임을 시작할 수 있어요.');
      return;
    }
    try {
      await SupabaseService.startMeeting(widget.meeting.id);
      if (!mounted) return;
      setState(() => widget.meeting.status = MeetingStatus.started);
      await _sendMessage(
        text: '모임이 시작되었어요.\n이제 신규 참여자는 들어올 수 없어요.',
        type: 'system',
      );
    } catch (e) {
      _showSnackBar('모임 시작에 실패했어요: $e');
    }
  }

  Future<void> _markMeetingComplete() async {
    if (widget.meeting.hostId != SupabaseService.userId) {
      _showSnackBar('모임장만 모임을 완료할 수 있어요.');
      return;
    }
    try {
      await SupabaseService.completeMeeting(widget.meeting.id);
      if (!mounted) return;
      setState(() => widget.meeting.status = MeetingStatus.completed);
      await _sendMessage(
        text: '오늘 모임이 완료되었어요!\n모임장은 정산을 진행해주세요',
        type: 'system',
      );
    } catch (e) {
      _showSnackBar('모임 완료에 실패했어요: $e');
    }
  }

  Future<void> _sendRandomPick() async {
    final members = await SupabaseService.getMeetingMembers(widget.meeting.id);
    final names = members
        .map((m) {
          final user = m['users'] as Map<String, dynamic>?;
          return (user?['nickname'] ?? user?['name'] ?? '').toString().trim();
        })
        .where((name) => name.isNotEmpty)
        .toList();

    if (names.isEmpty) {
      _showSnackBar('랜덤으로 뽑을 멤버가 아직 없어요.');
      return;
    }

    final picked = names[Random().nextInt(names.length)];
    await _sendMessage(text: '랜덤 뽑기 결과: $picked');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.meeting.title.isEmpty ? '모임 제목' : widget.meeting.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    itemCount: _messages.isEmpty ? 1 : _messages.length,
                    itemBuilder: (context, index) {
                      if (_messages.isEmpty) return const _EmptyChatHint();
                      return _MessageBubble(
                        message: _messages[index],
                        meeting: widget.meeting,
                        onSettlementCompleted: () => _sendMessage(
                          text: '정산이 완료되었어요.\n모임 평가까지 모두 마쳤습니다.',
                          type: 'system',
                        ),
                      );
                    },
                  ),
          ),
          _QuickActions(
            isHost: widget.meeting.hostId == SupabaseService.userId,
            status: widget.meeting.status,
            onRandomPick: _sendRandomPick,
            onStart: _markMeetingStarted,
            onComplete: _markMeetingComplete,
            onSettlement: _openSettlementRequest,
          ),
          _InputBar(
            controller: _controller,
            sending: _sending,
            onSubmitted: (_) => _sendMessage(),
            onSend: () => _sendMessage(),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final bool isHost;
  final MeetingStatus status;
  final VoidCallback onRandomPick;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onSettlement;

  const _QuickActions({
    required this.isHost,
    required this.status,
    required this.onRandomPick,
    required this.onStart,
    required this.onComplete,
    required this.onSettlement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _QuickActionButton(label: '랜덤 뽑기', onTap: onRandomPick),
            if (isHost && status == MeetingStatus.open) ...[
              const SizedBox(width: 10),
              _QuickActionButton(label: '모임 시작', onTap: onStart),
            ],
            if (isHost && status == MeetingStatus.started) ...[
              const SizedBox(width: 10),
              _QuickActionButton(label: '모임 완료', onTap: onComplete),
            ],
            if (isHost) ...[
              const SizedBox(width: 10),
              _QuickActionButton(label: '1/N 정산하기', onTap: onSettlement),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 27,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSubmitted,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFDADADA))),
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: controller,
                  onSubmitted: onSubmitted,
                  minLines: 1,
                  maxLines: 1,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: '모임 멤버들과 이야기 해보세요!',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF909090),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 13),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(0),
                      borderSide: const BorderSide(color: Color(0xFFDADADA)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(0),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 35,
              height: 35,
              child: ElevatedButton(
                onPressed: sending ? null : onSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.textLight,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded, size: 19),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final MeetingModel meeting;
  final Future<void> Function() onSettlementCompleted;

  const _MessageBubble({
    required this.message,
    required this.meeting,
    required this.onSettlementCompleted,
  });

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.system) {
      return _CompletionNotice(message: message);
    }

    if (message.type == MessageType.dutchPay) {
      return _SettlementRequestBubble(
        message: message,
        meeting: meeting,
        onSettlementCompleted: onSettlementCompleted,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isMe) ...[
            _ChatAvatar(
              label: message.senderName.isNotEmpty
                  ? message.senderName.substring(0, 1)
                  : '밥',
              userId: message.senderId,
            ),
            const SizedBox(width: 9),
          ],
          if (message.isMe) _MessageTime(time: message.time),
          if (message.isMe) const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: message.isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!message.isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.senderName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFA1A1A1),
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.62,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: message.isMe
                        ? AppColors.primary
                        : const Color(0xFFDADADA),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(message.isMe ? 6 : 0),
                      topRight: Radius.circular(message.isMe ? 0 : 6),
                      bottomLeft: const Radius.circular(6),
                      bottomRight: const Radius.circular(6),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: message.isMe ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!message.isMe) const SizedBox(width: 6),
          if (!message.isMe) _MessageTime(time: message.time),
        ],
      ),
    );
  }
}

class _CompletionNotice extends StatelessWidget {
  final ChatMessage message;

  const _CompletionNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    final isCompletion = message.text.contains('모임이 완료');
    if (!isCompletion) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              message.text,
              style: const TextStyle(fontSize: 12, color: AppColors.primary),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        _TimeDivider(time: message.time),
        const SizedBox(height: 25),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          decoration: BoxDecoration(
            color: AppColors.primaryBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDADADA)),
          ),
          child: const Column(
            children: [
              Text(
                '오늘 모임이 완료되었어요!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 5),
              Text(
                '모임장은 정산을 진행해주세요',
                style: TextStyle(fontSize: 13, color: Colors.black),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
      ],
    );
  }
}

class _SettlementRequestBubble extends StatelessWidget {
  final ChatMessage message;
  final MeetingModel meeting;
  final Future<void> Function() onSettlementCompleted;

  const _SettlementRequestBubble({
    required this.message,
    required this.meeting,
    required this.onSettlementCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final settlement = _SettlementMessage.parse(message.text);
    final cardWidth = min(223.0, MediaQuery.sizeOf(context).width * 0.62);

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _MessageTime(time: message.time),
          const SizedBox(width: 6),
          Container(
            width: cardWidth,
            padding: const EdgeInsets.fromLTRB(19, 30, 19, 19),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFDADADA)),
            ),
            child: Column(
              children: [
                const Text(
                  '오늘 모임이 완료되었어요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const Text(
                  '1인 정산 비용',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_formatWon(settlement.perPersonAmount)}원',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                    width: 110, height: 1, color: const Color(0xFFDADADA)),
                const SizedBox(height: 15),
                Text(
                  '총 비용: ${_formatWon(settlement.totalAmount)}원',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF909090)),
                ),
                const SizedBox(height: 12),
                const Text(
                  '서로의 신뢰를 위해 잊지 않게\n정산 금액을 확인해주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () async {
                      final completed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettlementScreen(
                            meeting: meeting,
                            isHost: meeting.hostId == SupabaseService.userId,
                            totalAmount: settlement.totalAmount,
                            bankInfo: settlement.bankInfo,
                            memberNames: settlement.memberNames,
                          ),
                        ),
                      );
                      if (completed == true &&
                          meeting.hostId == SupabaseService.userId) {
                        await onSettlementCompleted();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      '확인하기',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
}

class _SettlementMessage {
  final int totalAmount;
  final int perPersonAmount;
  final String bankInfo;
  final List<String> memberNames;

  const _SettlementMessage({
    required this.totalAmount,
    required this.perPersonAmount,
    required this.bankInfo,
    required this.memberNames,
  });

  static _SettlementMessage parse(String text) {
    var total = 0;
    var perPerson = 0;
    var bankInfo = '신한은행 1000-000-000001';
    var memberNames = <String>[];

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.startsWith('total:')) {
        total = int.tryParse(line.replaceFirst('total:', '').trim()) ?? total;
      } else if (line.startsWith('per_person:')) {
        perPerson = int.tryParse(line.replaceFirst('per_person:', '').trim()) ??
            perPerson;
      } else if (line.startsWith('bank:')) {
        final parsedBank = line.replaceFirst('bank:', '').trim();
        if (parsedBank.isNotEmpty) bankInfo = parsedBank;
      } else if (line.startsWith('members:')) {
        memberNames = line
            .replaceFirst('members:', '')
            .split(',')
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .toList();
      }
    }

    if (total == 0 || perPerson == 0) {
      final numbers = RegExp(r'\d[\d,]*')
          .allMatches(text)
          .map((match) {
            return int.tryParse(match.group(0)!.replaceAll(',', '')) ?? 0;
          })
          .where((value) => value > 0)
          .toList();
      if (numbers.isNotEmpty) total = total == 0 ? numbers.first : total;
      if (numbers.length > 1) {
        perPerson = perPerson == 0 ? numbers[1] : perPerson;
      }
    }

    return _SettlementMessage(
      totalAmount: total,
      perPersonAmount: perPerson,
      bankInfo: bankInfo,
      memberNames: memberNames,
    );
  }
}

class _TimeDivider extends StatelessWidget {
  final DateTime time;

  const _TimeDivider({required this.time});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFA1A1A1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _MessageTime(time: time, fontSize: 12),
        ),
        const Expanded(child: Divider(color: Color(0xFFA1A1A1))),
      ],
    );
  }
}

class _MessageTime extends StatelessWidget {
  final DateTime time;
  final double fontSize;

  const _MessageTime({required this.time, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    final period = time.hour < 12 ? '오전' : '오후';
    final hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    return Text(
      '$period $hour:$minute',
      style: TextStyle(fontSize: fontSize, color: const Color(0xFF7C7C7C)),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  final String label;
  final String userId;

  const _ChatAvatar({required this.label, required this.userId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: userId.isEmpty
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PublicProfileScreen(userId: userId),
                ),
              ),
      child: CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFFFFE5DD),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _EmptyChatHint extends StatelessWidget {
  const _EmptyChatHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 180),
      child: Center(
        child: Text(
          '모임 멤버들과 첫 이야기를 시작해보세요',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ),
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
