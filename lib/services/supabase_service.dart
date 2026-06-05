// lib/services/supabase_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  static final _client = Supabase.instance.client;

  static String get userId => currentUser?.id ?? 'anonymous';

  // ─── 유저 저장 ───
  static Future<void> saveUser(UserModel user) async {
    await _client.from('users').upsert({
      'id': user.id,
      'name': user.name,
      'tags': user.tags,
      'age': user.age,
      'nickname': user.nickname,
      'avatar_url': user.avatarUrl,
      'university': user.university,
      'department': user.department,
      'student_id': user.studentId,
    });
  }

  // ─── 프로필 업데이트 ───
  static Future<void> updateProfile(UserModel user) async {
    // null 포함 모든 컬럼을 명시적으로 전송 (null이면 DB에서 지움)
    await _client.from('users').update({
      'name': user.name,
      'tags': user.tags,
      'age': user.age,
      'nickname': user.nickname,
      'avatar_url': user.avatarUrl,
      'university': user.university,
      'department': user.department,
      'student_id': user.studentId,
    }).eq('id', user.id);
    currentUser = user;
  }

  // ─── 아바타 이미지 업로드 ───
  static Future<String?> uploadAvatar(Uint8List bytes, String fileName) async {
    try {
      final path = '$userId/$fileName';
      await _client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return _client.storage.from('avatars').getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  // ─── 유저 프로필 로드 (앱 시작 시) ───
  static Future<bool> loadCurrentUser(String userId) async {
    try {
      final data =
          await _client.from('users').select().eq('id', userId).maybeSingle();
      if (data != null) {
        currentUser = UserModel.fromJson(data);
        return true; // 프로필 있음
      }
      return false; // 프로필 없음 → 온보딩 필요
    } catch (e) {
      debugPrint('loadCurrentUser 에러: \$e');
      return false;
    }
  }

  // ─── 로그아웃 ───
  static Future<void> signOut() async {
    currentUser = null;
    await _client.auth.signOut();
  }

  // ─── 모임 목록 불러오기 ───
  static Future<List<MeetingModel>> getMeetings() async {
    final data = await _client
        .from('meetings')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((m) => MeetingModel.fromJson(m)).toList();
  }

  static Future<Set<String>> getBlockedUserIds() async {
    if (userId == 'anonymous') return {};
    final data = await _client
        .from('blocked_matches')
        .select('blocked_user_id')
        .eq('blocker_id', userId);
    return (data as List).map((m) => m['blocked_user_id'] as String).toSet();
  }

  static Future<void> blockUserFromRematch(String blockedUserId) async {
    if (userId == 'anonymous' || blockedUserId == userId) return;
    await _client.from('blocked_matches').upsert({
      'blocker_id': userId,
      'blocked_user_id': blockedUserId,
    });
  }

  static Future<List<MeetingModel>> filterMeetingsForMatching(
    List<MeetingModel> meetings,
  ) async {
    final blockedUserIds = await getBlockedUserIds();
    if (blockedUserIds.isEmpty) return meetings;

    final memberRows = await _client
        .from('meeting_members')
        .select('meeting_id')
        .inFilter('user_id', blockedUserIds.toList());
    final blockedMeetingIds =
        (memberRows as List).map((m) => m['meeting_id'] as String).toSet();

    return meetings
        .where((m) =>
            !blockedUserIds.contains(m.hostId) &&
            !blockedMeetingIds.contains(m.id))
        .toList();
  }

  static Future<List<MeetingModel>> getMeetingsExcludingBlocked() async {
    final meetings = await getMeetings();
    return filterMeetingsForMatching(meetings);
  }

  // ─── 모임 생성 ───
  static Future<MeetingModel?> createMeeting(MeetingModel meeting) async {
    final data = await _client
        .from('meetings')
        .insert(meeting.toJson())
        .select()
        .single();
    return MeetingModel.fromJson(data);
  }

  // ─── 모임 참여 ───
  static Future<void> joinMeeting(String meetingId) async {
    final blockedUserIds = await getBlockedUserIds();
    if (blockedUserIds.isNotEmpty) {
      final members = await getMeetingMembers(meetingId);
      final hasBlockedMember = members
          .any((m) => blockedUserIds.contains(m['user_id'] as String? ?? ''));
      if (hasBlockedMember) {
        throw Exception('다시 만나지 않기로 한 사람이 있는 모임입니다.');
      }
    }

    await _client.from('meeting_members').upsert({
      'meeting_id': meetingId,
      'user_id': userId,
    });
    final meeting = await _client
        .from('meetings')
        .select('current_members')
        .eq('id', meetingId)
        .single();
    final current = (meeting['current_members'] as int?) ?? 1;
    await _client
        .from('meetings')
        .update({'current_members': current + 1}).eq('id', meetingId);
  }

  // ─── 모임 참여 취소 ───
  static Future<void> leaveMeeting(String meetingId) async {
    await _client.from('meeting_members').delete().match({
      'meeting_id': meetingId,
      'user_id': userId,
    });
    final meeting = await _client
        .from('meetings')
        .select('current_members')
        .eq('id', meetingId)
        .single();
    final current = (meeting['current_members'] as int?) ?? 1;
    await _client.from('meetings').update(
        {'current_members': (current - 1).clamp(0, 999)}).eq('id', meetingId);
  }

  // ─── 내가 참여한 모임 ID 목록 ───
  static Future<Set<String>> getMyMeetingIds() async {
    if (userId == 'anonymous') return {};
    final data = await _client
        .from('meeting_members')
        .select('meeting_id')
        .eq('user_id', userId);
    return (data as List).map((m) => m['meeting_id'] as String).toSet();
  }

  // ─── 모임 멤버 목록 불러오기 (프로필 포함) ───
  static Future<List<Map<String, dynamic>>> getMeetingMembers(
      String meetingId) async {
    try {
      // meeting_members 테이블에서 user_id 가져오고 users 테이블 join
      final data = await _client
          .from('meeting_members')
          .select('user_id, users(id, name, nickname, avatar_url)')
          .eq('meeting_id', meetingId);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('[SupabaseService] getMeetingMembers 오류: \$e');
      return [];
    }
  }

  // ─── 채팅 메시지 불러오기 ───
  static Future<List<ChatMessage>> getMessages(String meetingId) async {
    final data = await _client
        .from('messages')
        .select()
        .eq('meeting_id', meetingId)
        .order('created_at', ascending: true);
    return (data as List).map((m) => ChatMessage.fromJson(m, userId)).toList();
  }

  // ─── 메시지 전송 ───
  static Future<void> sendMessage({
    required String meetingId,
    required String text,
    String type = 'text',
  }) async {
    await _client.from('messages').insert({
      'meeting_id': meetingId,
      'sender_id': userId,
      'sender_name': currentUser?.name ?? '익명',
      'text': text,
      'type': type,
    });
  }

  // ─── 실시간 메시지 구독 ───
  static RealtimeChannel subscribeMessages(
    String meetingId,
    void Function(ChatMessage) onMessage,
  ) {
    return _client
        .channel('messages_$meetingId')
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
            final msg = ChatMessage.fromJson(payload.newRecord, userId);
            onMessage(msg);
          },
        )
        .subscribe();
  }

  // ─── 일치도 계산 ───
  static Future<String> createSettlement({
    required String meetingId,
    required int totalAmount,
    required int perPersonAmount,
    required String bankInfo,
    required List<Map<String, dynamic>> members,
    String? memo,
  }) async {
    final settlement = await _client
        .from('settlements')
        .insert({
          'meeting_id': meetingId,
          'requester_id': userId,
          'total_amount': totalAmount,
          'per_person_amount': perPersonAmount,
          'bank_info': bankInfo,
          'memo': memo,
          'status': 'requested',
        })
        .select('id')
        .single();

    final settlementId = settlement['id'] as String;
    if (members.isNotEmpty) {
      await _client.from('settlement_members').insert(
            members
                .map(
                  (member) => {
                    'settlement_id': settlementId,
                    'user_id': member['user_id'],
                    'user_name': member['user_name'],
                    'amount': member['amount'],
                    'status': 'requested',
                  },
                )
                .toList(),
          );
    }
    return settlementId;
  }

  static Future<Map<String, dynamic>?> getSettlement(
    String settlementId,
  ) async {
    return await _client
        .from('settlements')
        .select()
        .eq('id', settlementId)
        .maybeSingle();
  }

  static Future<List<Map<String, dynamic>>> getSettlementMembers(
    String settlementId,
  ) async {
    final data = await _client
        .from('settlement_members')
        .select()
        .eq('settlement_id', settlementId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> updateSettlementMemberStatus({
    required String settlementId,
    required String memberUserId,
    required String status,
  }) async {
    final updates = <String, dynamic>{'status': status};
    if (status == 'paid') {
      updates['paid_at'] = DateTime.now().toIso8601String();
    }
    if (status == 'confirmed') {
      updates['confirmed_at'] = DateTime.now().toIso8601String();
    }

    await _client
        .from('settlement_members')
        .update(updates)
        .eq('settlement_id', settlementId)
        .eq('user_id', memberUserId);
  }

  static Future<void> syncSettlementStatus(String settlementId) async {
    final members = await getSettlementMembers(settlementId);
    if (members.isEmpty) return;

    final allConfirmed =
        members.every((member) => member['status'] == 'confirmed');
    final hasPaid = members.any(
      (member) => member['status'] == 'paid' || member['status'] == 'confirmed',
    );
    final status =
        allConfirmed ? 'completed' : (hasPaid ? 'in_progress' : null);
    if (status == null) return;

    await _client.from('settlements').update({
      'status': status,
      if (allConfirmed) 'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', settlementId);
  }

  static int calcMatch(List<String> myTags, List<String> meetingTags) {
    if (myTags.isEmpty || meetingTags.isEmpty) return 0;
    final matches = myTags.where((t) => meetingTags.contains(t)).length;
    return ((matches / meetingTags.length) * 100).round().clamp(0, 100);
  }
}
