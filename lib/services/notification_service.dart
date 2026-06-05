// lib/services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String? meetingId;
  final DateTime time;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.meetingId,
    required this.time,
    this.isRead = false,
  });
}

enum NotificationType { newMessage, newMember, meetingFull }

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final List<AppNotification> _notifications = [];
  final List<RealtimeChannel> _channels = [];

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // ─── 내가 참여한 모임들 구독 시작 ───
  Future<void> startListening(List<String> myMeetingIds) async {
    // 기존 구독 해제
    await stopListening();
    if (myMeetingIds.isEmpty) return;

    final client = Supabase.instance.client;

    // 1. 새 채팅 메시지 감지
    for (final meetingId in myMeetingIds) {
      final msgChannel = client
          .channel('notif_msg_$meetingId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'meeting_id',
              value: meetingId,
            ),
            callback: (payload) {
              final record = payload.newRecord;
              final senderId = record['sender_id'] as String?;
              final senderName = record['sender_name'] as String? ?? '누군가';
              final text = record['text'] as String? ?? '';
              final msgType = record['type'] as String? ?? 'text';

              // 내가 보낸 메시지는 알림 제외
              if (senderId == currentUser?.id) return;
              if (msgType == 'system') return;

              _addNotification(AppNotification(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: '💬 새 메시지',
                body: '$senderName: $text',
                type: NotificationType.newMessage,
                meetingId: meetingId,
                time: DateTime.now(),
              ));
            },
          )
          .subscribe();
      _channels.add(msgChannel);
    }

    // 2. 새 멤버 참여 감지
    for (final meetingId in myMeetingIds) {
      final memberChannel = client
          .channel('notif_member_$meetingId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'meeting_members',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'meeting_id',
              value: meetingId,
            ),
            callback: (payload) async {
              final record = payload.newRecord;
              final userId = record['user_id'] as String?;

              // 내가 참여한 건 알림 제외
              if (userId == currentUser?.id) return;

              // 유저 이름 조회
              String userName = '새로운 멤버';
              try {
                final userData = await Supabase.instance.client
                    .from('users')
                    .select('name')
                    .eq('id', userId!)
                    .maybeSingle();
                if (userData != null) userName = userData['name'] as String;
              } catch (_) {}

              _addNotification(AppNotification(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: '👤 새 멤버 참여',
                body: '$userName님이 모임에 참여했어요!',
                type: NotificationType.newMember,
                meetingId: meetingId,
                time: DateTime.now(),
              ));
            },
          )
          .subscribe();
      _channels.add(memberChannel);
    }
  }

  // ─── 구독 해제 ───
  Future<void> stopListening() async {
    for (final ch in _channels) {
      await ch.unsubscribe();
    }
    _channels.clear();
  }

  // ─── 알림 추가 ───
  void _addNotification(AppNotification notif) {
    _notifications.insert(0, notif);
    // 최대 50개 유지
    if (_notifications.length > 50) _notifications.removeLast();
    notifyListeners();
  }

  // ─── 전체 읽음 처리 ───
  void markAllRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  // ─── 단일 읽음 처리 ───
  void markRead(String id) {
    final notif = _notifications.firstWhere((n) => n.id == id, orElse: () => _notifications.first);
    notif.isRead = true;
    notifyListeners();
  }

  // ─── 전체 삭제 ───
  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }
}
