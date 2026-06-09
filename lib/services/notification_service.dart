// lib/services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

class AppNotification {
  final String id;
  String title;
  String body;
  final NotificationType type;
  final String? meetingId;
  DateTime time;
  bool isRead;
  int messageCount;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.meetingId,
    required this.time,
    this.isRead = false,
    this.messageCount = 1,
  });
}

enum NotificationType {
  newMessage,
  newMember,
  meetingFull,
  paymentConfirmRequest,
}

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final List<AppNotification> _notifications = [];
  final List<RealtimeChannel> _channels = [];

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.fold<int>(0, (total, notification) {
        if (notification.isRead) return total;
        if (notification.type == NotificationType.newMessage) {
          return total + notification.messageCount;
        }
        return total + 1;
      });

  Future<void> startListening(List<String> myMeetingIds) async {
    await stopListening();
    if (myMeetingIds.isEmpty) return;

    final client = Supabase.instance.client;

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
              final senderName = record['sender_name'] as String? ?? '이름 없음';
              final text = record['text'] as String? ?? '';
              final msgType = record['type'] as String? ?? 'text';

              if (senderId == currentUser?.id) return;
              if (msgType == 'system') return;

              if (msgType == 'paymentConfirmRequest') {
                _addNotification(AppNotification(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  title: '입금 확인 요청',
                  body: '$senderName님이 입금 확인을 요청했어요',
                  type: NotificationType.paymentConfirmRequest,
                  meetingId: meetingId,
                  time: DateTime.now(),
                ));
                return;
              }

              _addMessageNotification(
                meetingId: meetingId,
                senderName: senderName,
                preview: text,
              );
            },
          )
          .subscribe();
      _channels.add(msgChannel);
    }

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

              if (userId == currentUser?.id) return;

              var userName = '새로운 멤버';
              try {
                final userData = await Supabase.instance.client
                    .from('users')
                    .select('name')
                    .eq('id', userId!)
                    .maybeSingle();
                if (userData != null) userName = userData['name'] as String;
              } catch (_) {}

              _addNotification(AppNotification(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                title: '새 멤버 참여',
                body: '$userName님이 모임에 참여했어요',
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

  Future<void> stopListening() async {
    for (final ch in _channels) {
      await ch.unsubscribe();
    }
    _channels.clear();
  }

  void _addMessageNotification({
    required String meetingId,
    required String senderName,
    required String preview,
  }) {
    final now = DateTime.now();
    final index = _notifications.indexWhere(
      (notification) =>
          notification.type == NotificationType.newMessage &&
          notification.meetingId == meetingId,
    );

    if (index == -1) {
      _addNotification(AppNotification(
        id: now.microsecondsSinceEpoch.toString(),
        title: '새 메시지 1개',
        body: '$senderName: $preview',
        type: NotificationType.newMessage,
        meetingId: meetingId,
        time: now,
      ));
      return;
    }

    final notification = _notifications.removeAt(index);
    final nextCount = notification.isRead ? 1 : notification.messageCount + 1;
    notification
      ..title = '새 메시지 $nextCount개'
      ..body = '$senderName: $preview'
      ..time = now
      ..isRead = false
      ..messageCount = nextCount;

    _notifications.insert(0, notification);
    notifyListeners();
  }

  void _addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    if (_notifications.length > 50) _notifications.removeLast();
    notifyListeners();
  }

  void markAllRead() {
    for (final notification in _notifications) {
      notification.isRead = true;
    }
    notifyListeners();
  }

  void markRead(String id) {
    final index =
        _notifications.indexWhere((notification) => notification.id == id);
    if (index == -1) return;
    _notifications[index].isRead = true;
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }
}
