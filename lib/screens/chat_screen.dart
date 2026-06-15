// lib/screens/chat_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../navigation/app_tab_events.dart';
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
  RealtimeChannel? _meetingChannel;
  bool _loading = true;
  bool _sending = false;
  bool _leavingCompletedRoom = false;
  bool _completingMeeting = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeRealtime();
    _subscribeMeetingStatus();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _meetingChannel?.unsubscribe();
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

  void _subscribeMeetingStatus() {
    _meetingChannel = SupabaseService.subscribeMeetingStatus(
      widget.meeting.id,
      (status) {
        if (!mounted) return;
        if (widget.meeting.status != status) {
          setState(() => widget.meeting.status = status);
        }
        if (status == MeetingStatus.completed && !_completingMeeting) {
          _leaveCompletedChat();
        }
      },
    );
  }

  void _leaveCompletedChat() {
    if (_leavingCompletedRoom || !mounted) return;
    _leavingCompletedRoom = true;
    _controller.clear();
    AppTabEvents.goHome();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
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
    if (widget.meeting.status == MeetingStatus.completed && type == 'text') {
      _showSnackBar(
          '\uC644\uB8CC\uB41C \uBAA8\uC784\uC5D0\uC11C\uB294 \uCC44\uD305\uD560 \uC218 \uC5C6\uC5B4\uC694.');
      return;
    }

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
        'settlement_id:${result.settlementId}',
        'total:${result.totalAmount}',
        'per_person:${result.perPersonAmount}',
        'bank:$bankInfo',
        if (result.receiptImageUrl?.isNotEmpty == true)
          'image:${result.receiptImageUrl}',
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
        text:
            '\uBAA8\uC784\uC774 \uC2DC\uC791\uB418\uC5C8\uC5B4\uC694.\n\uC774\uC81C \uC2E0\uADDC \uCC38\uC5EC\uC790\uB294 \uB4E4\uC5B4\uC62C \uC218 \uC5C6\uC5B4\uC694.',
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
    _completingMeeting = true;
    try {
      await SupabaseService.completeMeeting(widget.meeting.id);
      if (!mounted) return;
      setState(() => widget.meeting.status = MeetingStatus.completed);
      await _sendMessage(
        text:
            '\uC624\uB298 \uBAA8\uC784\uC774 \uC644\uB8CC\uB418\uC5C8\uC5B4\uC694!',
        type: 'system',
      );
      _leaveCompletedChat();
    } catch (e) {
      _completingMeeting = false;
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

  Future<void> _openBaeminTogether() async {
    final trimmed = widget.meeting.baeminTogetherUrl?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final url = trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'https://$trimmed';
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showSnackBar('함께주문 링크 형식이 올바르지 않아요.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) _showSnackBar('함께주문 링크를 열지 못했어요.');
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
                        onSettlementCompleted: () async {
                          if (mounted) setState(() {});
                        },
                      );
                    },
                  ),
          ),
          if (widget.meeting.status == MeetingStatus.completed)
            const _CompletedChatFooter()
          else ...[
            _QuickActions(
              isHost: widget.meeting.hostId == SupabaseService.userId,
              status: widget.meeting.status,
              hasBaeminTogetherUrl:
                  (widget.meeting.baeminTogetherUrl?.trim().isNotEmpty ??
                      false),
              onRandomPick: _sendRandomPick,
              onStart: _markMeetingStarted,
              onComplete: _markMeetingComplete,
              onSettlement: _openSettlementRequest,
              onBaeminTogether: _openBaeminTogether,
            ),
            _InputBar(
              controller: _controller,
              sending: _sending,
              onSubmitted: (_) => _sendMessage(),
              onSend: () => _sendMessage(),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompletedChatFooter extends StatelessWidget {
  const _CompletedChatFooter();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFDADADA))),
        ),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '\uC644\uB8CC\uB41C \uBAA8\uC784\uC774\uC5D0\uC694',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
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
  final bool hasBaeminTogetherUrl;
  final VoidCallback onBaeminTogether;

  const _QuickActions({
    required this.isHost,
    required this.status,
    required this.onRandomPick,
    required this.onStart,
    required this.onComplete,
    required this.onSettlement,
    required this.hasBaeminTogetherUrl,
    required this.onBaeminTogether,
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
            if (hasBaeminTogetherUrl) ...[
              _QuickActionButton(label: '배민 함께주문', onTap: onBaeminTogether),
              const SizedBox(width: 10),
            ],
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
                '\uC624\uB298 \uBAA8\uC784\uC774 \uC644\uB8CC\uB418\uC5C8\uC5B4\uC694!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
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

    return FutureBuilder<Map<String, dynamic>?>(
      future: SupabaseService.getSettlementState(
        settlementId: settlement.settlementId,
        meetingId: meeting.id,
      ),
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isChecking = snapshot.connectionState != ConnectionState.done;
        final isCompleted = state?['status'] == 'completed';
        final totalAmount =
            (state?['total_amount'] as num?)?.toInt() ?? settlement.totalAmount;
        final members = List<Map<String, dynamic>>.from(
          (state?['members'] as List?) ?? const [],
        );
        final perPersonAmount = members.isNotEmpty
            ? ((members.first['amount'] as num?)?.toInt() ??
                settlement.perPersonAmount)
            : settlement.perPersonAmount;

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
                padding: EdgeInsets.fromLTRB(19, 30, 19, isCompleted ? 22 : 19),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFDADADA)),
                ),
                child: Column(
                  children: [
                    Text(
                      isCompleted
                          ? '\uC815\uC0B0\uC774 \uC644\uB8CC\uB418\uC5C8\uC5B4\uC694'
                          : '\uC624\uB298 \uBAA8\uC784\uC774 \uC644\uB8CC\uB418\uC5C8\uC5B4\uC694!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1\uC778 \uC815\uC0B0 \uBE44\uC6A9',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatWon(perPersonAmount)}\uC6D0',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: 110,
                      height: 1,
                      color: const Color(0xFFDADADA),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      '\uCD1D \uBE44\uC6A9: ${_formatWon(totalAmount)}\uC6D0',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF909090),
                      ),
                    ),
                    if (isCompleted) ...[
                      const SizedBox(height: 14),
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          '\uC815\uC0B0 \uC694\uC57D',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ] else if (isChecking) ...[
                      const SizedBox(height: 14),
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      const Text(
                        '\uC11C\uB85C\uC758 \uC2E0\uB8B0\uB97C \uC704\uD574 \uC787\uC9C0 \uC54A\uAC8C\n\uC815\uC0B0 \uAE08\uC561\uC744 \uD655\uC778\uD574\uC8FC\uC138\uC694',
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
                                  isHost:
                                      meeting.hostId == SupabaseService.userId,
                                  settlementId: settlement.settlementId,
                                  totalAmount: settlement.totalAmount,
                                  bankInfo: settlement.bankInfo,
                                  receiptImageUrl: settlement.receiptImageUrl,
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
                            '\uD655\uC778\uD558\uAE30',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettlementMessage {
  final String? settlementId;
  final int totalAmount;
  final int perPersonAmount;
  final String bankInfo;
  final String? receiptImageUrl;
  final List<String> memberNames;

  const _SettlementMessage({
    this.settlementId,
    required this.totalAmount,
    required this.perPersonAmount,
    required this.bankInfo,
    this.receiptImageUrl,
    required this.memberNames,
  });

  static _SettlementMessage parse(String text) {
    String? settlementId;
    var total = 0;
    var perPerson = 0;
    var bankInfo = '신한은행 1000-000-000001';
    String? receiptImageUrl;
    var memberNames = <String>[];

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.startsWith('settlement_id:')) {
        final parsedId = line.replaceFirst('settlement_id:', '').trim();
        if (parsedId.isNotEmpty) settlementId = parsedId;
      } else if (line.startsWith('id:')) {
        final parsedId = line.replaceFirst('id:', '').trim();
        if (parsedId.isNotEmpty) settlementId = parsedId;
      } else if (line.startsWith('total:')) {
        total = int.tryParse(line.replaceFirst('total:', '').trim()) ?? total;
      } else if (line.startsWith('per_person:')) {
        perPerson = int.tryParse(line.replaceFirst('per_person:', '').trim()) ??
            perPerson;
      } else if (line.startsWith('bank:')) {
        final parsedBank = line.replaceFirst('bank:', '').trim();
        if (parsedBank.isNotEmpty) bankInfo = parsedBank;
      } else if (line.startsWith('image:')) {
        final parsedImageUrl = line.replaceFirst('image:', '').trim();
        if (parsedImageUrl.isNotEmpty) receiptImageUrl = parsedImageUrl;
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
      settlementId: settlementId,
      totalAmount: total,
      perPersonAmount: perPerson,
      bankInfo: bankInfo,
      receiptImageUrl: receiptImageUrl,
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
