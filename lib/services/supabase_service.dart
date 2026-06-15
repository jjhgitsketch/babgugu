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
      'gender': user.gender,
      'school_email': user.schoolEmail,
      'student_verified': user.studentVerified,
      'student_verified_at': user.studentVerifiedAt?.toIso8601String(),
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

    try {
      await _client.from('users').update({
        'gender': user.gender,
      }).eq(
        'id',
        user.id,
      );
    } catch (e) {
      debugPrint('[SupabaseService] 학생 인증 컬럼 미연결: $e');
    }
    currentUser = user;
  }

  static Future<void> sendSchoolEmailOtp(String email) async {
    if (userId == 'anonymous') throw Exception('로그인이 필요해요.');

    final response = await _client.functions.invoke(
      'send-school-verification',
      body: {'email': email},
    );
    _throwFunctionError(response);
  }

  static Future<void> verifySchoolEmailOtp({
    required String email,
    required String token,
  }) async {
    if (userId == 'anonymous') throw Exception('로그인이 필요해요.');

    final response = await _client.functions.invoke(
      'verify-school-verification',
      body: {
        'email': email,
        'code': token,
      },
    );
    _throwFunctionError(response);

    final user = currentUser;
    if (user == null) return;
    final data = response.data;
    final verifiedAtText =
        data is Map ? data['student_verified_at'] as String? : null;
    final verifiedAt = verifiedAtText == null
        ? DateTime.now()
        : DateTime.parse(verifiedAtText).toLocal();
    final updated = user.copyWith(
      schoolEmail: email,
      studentVerified: true,
      studentVerifiedAt: verifiedAt,
    );
    currentUser = updated;
  }

  static void _throwFunctionError(FunctionResponse response) {
    if (response.status >= 200 && response.status < 300) return;

    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
    if (data is String && data.isNotEmpty) throw Exception(data);
    throw Exception('요청을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.');
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

  static Future<String?> uploadMeetingImage(
    Uint8List bytes,
    String fileName,
  ) async {
    return _uploadPublicImage(
      bucket: 'meeting-images',
      folder: 'meetings',
      bytes: bytes,
      fileName: fileName,
    );
  }

  static Future<String?> uploadSettlementImage(
    Uint8List bytes,
    String fileName,
  ) async {
    return _uploadPublicImage(
      bucket: 'settlement-images',
      folder: 'settlements',
      bytes: bytes,
      fileName: fileName,
    );
  }

  static Future<String?> _uploadPublicImage({
    required String bucket,
    required String folder,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path =
          '$userId/$folder/${DateTime.now().microsecondsSinceEpoch}_$safeName';
      await _client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _guessImageContentType(fileName),
            ),
          );
      return _client.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('[SupabaseService] image upload error: $e');
      return null;
    }
  }

  static String _guessImageContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  // ─── 유저 프로필 로드 (앱 시작 시) ───
  static Future<UserModel?> getUserById(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final data =
          await _client.from('users').select().eq('id', userId).maybeSingle();
      if (data == null) return null;
      return UserModel.fromJson(data);
    } catch (e) {
      debugPrint('[SupabaseService] getUserById 오류: $e');
      return null;
    }
  }

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
        .gt('current_members', 0)
        .order('created_at', ascending: false);
    return (data as List).map((m) => MeetingModel.fromJson(m)).toList();
  }

  static Future<MeetingModel?> getMeetingById(String meetingId) async {
    try {
      final data = await _client
          .from('meetings')
          .select()
          .eq('id', meetingId)
          .maybeSingle();
      if (data == null) return null;
      return MeetingModel.fromJson(data);
    } catch (e) {
      debugPrint('[SupabaseService] getMeetingById 오류: $e');
      return null;
    }
  }

  // ─── 모임 생성 ───
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
    final openMeetings = meetings
        .where((meeting) => meeting.status == MeetingStatus.open)
        .toList();
    return filterMeetingsForMatching(openMeetings);
  }

  static Future<MeetingModel?> createMeeting(MeetingModel meeting) async {
    final data = await _client
        .from('meetings')
        .insert(meeting.toJson())
        .select()
        .single();
    return MeetingModel.fromJson(data);
  }

  static Future<void> updateMeetingStatus({
    required String meetingId,
    required MeetingStatus status,
  }) async {
    final meeting = await getMeetingById(meetingId);
    if (meeting == null) throw Exception('모임을 찾을 수 없어요.');
    if (meeting.hostId != userId) {
      throw Exception('모임장만 모임 상태를 변경할 수 있어요.');
    }
    await _client.from('meetings').update({'status': status.dbValue}).eq(
      'id',
      meetingId,
    );
  }

  static Future<void> startMeeting(String meetingId) => updateMeetingStatus(
        meetingId: meetingId,
        status: MeetingStatus.started,
      );

  static Future<void> completeMeeting(String meetingId) => updateMeetingStatus(
        meetingId: meetingId,
        status: MeetingStatus.completed,
      );
  // ─── 모임 참여 ───
  static Future<void> joinMeeting(String meetingId) async {
    final meeting = await _client
        .from('meetings')
        .select('status, current_members, max_members')
        .eq('id', meetingId)
        .single();
    final status = MeetingStatusX.fromDb(meeting['status'] as String?);
    if (status != MeetingStatus.open) {
      throw Exception('이미 시작되었거나 완료된 모임에는 참여할 수 없어요.');
    }

    final current = (meeting['current_members'] as int?) ?? 0;
    final max = (meeting['max_members'] as int?) ?? 0;
    if (max > 0 && current >= max) {
      throw Exception('모집이 완료된 모임이에요.');
    }

    final existing = await _client
        .from('meeting_members')
        .select('meeting_id')
        .eq('meeting_id', meetingId)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing != null) return;

    final blockedUserIds = await getBlockedUserIds();
    if (blockedUserIds.isNotEmpty) {
      final members = await getMeetingMembers(meetingId);
      final hasBlockedMember = members
          .any((m) => blockedUserIds.contains(m['user_id'] as String? ?? ''));
      if (hasBlockedMember) {
        throw Exception('다시 만나지 않기로 한 사람이 있는 모임입니다.');
      }
    }

    await _client.from('meeting_members').insert({
      'meeting_id': meetingId,
      'user_id': userId,
    });

    final memberRows = await _client
        .from('meeting_members')
        .select('user_id')
        .eq('meeting_id', meetingId);
    await _client
        .from('meetings')
        .update({'current_members': (memberRows as List).length}).eq(
      'id',
      meetingId,
    );
  }

  // ─── 모임 참여 취소 ───
  static Future<void> leaveMeeting(String meetingId) async {
    await _client.from('meeting_members').delete().match({
      'meeting_id': meetingId,
      'user_id': userId,
    });

    final memberRows = await _client
        .from('meeting_members')
        .select('user_id')
        .eq('meeting_id', meetingId);
    final memberCount = (memberRows as List).length;

    if (memberCount == 0) {
      await _client.from('meetings').delete().eq('id', meetingId);
      return;
    }

    await _client
        .from('meetings')
        .update({'current_members': memberCount}).eq('id', meetingId);
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

  static Future<Set<String>> getSavedMeetingIds() async {
    if (userId == 'anonymous') return {};
    final data = await _client
        .from('saved_meetings')
        .select('meeting_id')
        .eq('user_id', userId);
    return (data as List).map((m) => m['meeting_id'] as String).toSet();
  }

  static Future<List<MeetingModel>> getSavedMeetings() async {
    final savedIds = await getSavedMeetingIds();
    if (savedIds.isEmpty) return [];

    final data = await _client
        .from('meetings')
        .select()
        .inFilter('id', savedIds.toList())
        .order('created_at', ascending: false);
    return (data as List).map((m) => MeetingModel.fromJson(m)).toList();
  }

  static Future<void> saveMeeting(String meetingId) async {
    if (userId == 'anonymous') return;
    await _client.from('saved_meetings').upsert({
      'user_id': userId,
      'meeting_id': meetingId,
    });
  }

  static Future<void> unsaveMeeting(String meetingId) async {
    if (userId == 'anonymous') return;
    await _client.from('saved_meetings').delete().match({
      'user_id': userId,
      'meeting_id': meetingId,
    });
  }

  static Future<TrustScore> getTrustScore(String reviewedUserId) async {
    try {
      final data = await _client
          .from('trust_reviews')
          .select('score')
          .eq('reviewed_user_id', reviewedUserId);
      final scores = (data as List)
          .map((row) => (row['score'] as num?)?.toDouble())
          .whereType<double>()
          .toList();
      if (scores.isEmpty) return TrustScore.empty;
      final total = scores.fold<double>(0, (sum, score) => sum + score);
      return TrustScore(average: total / scores.length, count: scores.length);
    } catch (e) {
      debugPrint('[SupabaseService] getTrustScore 오류: $e');
      return TrustScore.empty;
    }
  }

  static Future<bool> hasSubmittedTrustReview(String meetingId) async {
    if (userId == 'anonymous') return false;
    try {
      final data = await _client
          .from('trust_reviews')
          .select('reviewed_user_id')
          .eq('meeting_id', meetingId)
          .eq('reviewer_id', userId)
          .limit(1);
      return (data as List).isNotEmpty;
    } catch (e) {
      debugPrint('[SupabaseService] hasSubmittedTrustReview error: $e');
      return false;
    }
  }

  static Future<void> submitTrustReview({
    required String meetingId,
    required String reviewedUserId,
    required double score,
    String? comment,
  }) async {
    if (userId == 'anonymous' || reviewedUserId == userId) return;
    final normalizedScore = score.clamp(0, 5).toDouble();
    await _client.from('trust_reviews').upsert({
      'meeting_id': meetingId,
      'reviewer_id': userId,
      'reviewed_user_id': reviewedUserId,
      'score': normalizedScore,
      'comment': comment,
    }, onConflict: 'meeting_id,reviewer_id,reviewed_user_id');
  }

  static Future<Map<String, SoloPlaceScore>> getSoloPlaceScores(
    Iterable<String> placeIds,
  ) async {
    final ids = placeIds.toSet().where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return {};
    try {
      final data = await _client
          .from('solo_place_reviews')
          .select('place_id, score')
          .inFilter('place_id', ids);
      final totals = <String, double>{};
      final counts = <String, int>{};
      for (final row in data as List) {
        final placeId = row['place_id'] as String?;
        final score = (row['score'] as num?)?.toDouble();
        if (placeId == null || score == null) continue;
        totals[placeId] = (totals[placeId] ?? 0) + score;
        counts[placeId] = (counts[placeId] ?? 0) + 1;
      }
      return {
        for (final entry in totals.entries)
          entry.key: SoloPlaceScore(
            average: entry.value / counts[entry.key]!,
            count: counts[entry.key]!,
          ),
      };
    } catch (e) {
      debugPrint('[SupabaseService] getSoloPlaceScores 오류: $e');
      return {};
    }
  }

  static Future<void> submitSoloPlaceReview({
    required String placeId,
    required int score,
    required List<String> tags,
    String? comment,
  }) async {
    if (userId == 'anonymous') return;
    final normalizedScore = score.clamp(1, 5);
    await _client.from('solo_place_reviews').upsert({
      'place_id': placeId,
      'user_id': userId,
      'score': normalizedScore,
      'tags': tags,
      'comment': comment?.trim().isEmpty == true ? null : comment?.trim(),
    }, onConflict: 'place_id,user_id');
  }

  // ─── 채팅 메시지 불러오기 ───

  static Future<String> createSettlement({
    required String meetingId,
    required int totalAmount,
    required int perPersonAmount,
    required String bankInfo,
    String? receiptImageUrl,
    required List<Map<String, dynamic>> members,
  }) async {
    final settlement = await _client
        .from('settlements')
        .insert({
          'meeting_id': meetingId,
          'requester_id': userId == 'anonymous' ? null : userId,
          'total_amount': totalAmount,
          'per_person_amount': perPersonAmount,
          'bank_info': bankInfo,
          'memo': receiptImageUrl,
          'status': 'requested',
        })
        .select('id')
        .single();

    final settlementId = settlement['id'] as String;
    final memberRows = members
        .where((member) => (member['user_id'] as String?)?.isNotEmpty == true)
        .map((member) => {
              'settlement_id': settlementId,
              'user_id': member['user_id'],
              'user_name': member['user_name'],
              'amount': member['amount'] ?? perPersonAmount,
              'status': 'requested',
            })
        .toList();

    if (memberRows.isNotEmpty) {
      await _client.from('settlement_members').insert(memberRows);
    }

    return settlementId;
  }

  static Future<Map<String, dynamic>?> getSettlementState({
    String? settlementId,
    required String meetingId,
  }) async {
    try {
      Map<String, dynamic>? settlement;
      if (settlementId != null && settlementId.trim().isNotEmpty) {
        final data = await _client
            .from('settlements')
            .select()
            .eq('id', settlementId)
            .maybeSingle();
        if (data != null) settlement = Map<String, dynamic>.from(data);
      }

      if (settlement == null) {
        final rows = await _client
            .from('settlements')
            .select()
            .eq('meeting_id', meetingId)
            .order('created_at', ascending: false)
            .limit(1);
        if ((rows as List).isEmpty) return null;
        settlement = Map<String, dynamic>.from(rows.first as Map);
      }

      final members = await _client
          .from('settlement_members')
          .select(
              'settlement_id, user_id, user_name, amount, status, paid_at, confirmed_at')
          .eq('settlement_id', settlement['id'])
          .order('user_name', ascending: true);
      settlement['members'] = List<Map<String, dynamic>>.from(members as List);
      return settlement;
    } catch (e) {
      debugPrint('[SupabaseService] getSettlementState error: $e');
      return null;
    }
  }

  static Future<void> updateSettlementMemberStatus({
    required String settlementId,
    required String memberUserId,
    required String status,
  }) async {
    final now = DateTime.now().toIso8601String();
    final values = <String, dynamic>{'status': status};
    if (status == 'paid') values['paid_at'] = now;
    if (status == 'confirmed') values['confirmed_at'] = now;

    await _client.from('settlement_members').update(values).match({
      'settlement_id': settlementId,
      'user_id': memberUserId,
    });
  }

  static Future<void> completeSettlement(String settlementId) async {
    await _client.from('settlements').update({
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', settlementId);
  }

  static Future<List<Map<String, dynamic>>> getMeetingMembers(
    String meetingId,
  ) async {
    try {
      final data = await _client
          .from('meeting_members')
          .select('user_id, users(id, name, nickname, avatar_url)')
          .eq('meeting_id', meetingId);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('[SupabaseService] getMeetingMembers 오류: $e');
      return [];
    }
  }

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

  static RealtimeChannel subscribeMeetingStatus(
    String meetingId,
    void Function(MeetingStatus) onStatusChanged,
  ) {
    return _client
        .channel('meeting_status_$meetingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'meetings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: meetingId,
          ),
          callback: (payload) {
            final status = MeetingStatusX.fromDb(
              payload.newRecord['status'] as String?,
            );
            onStatusChanged(status);
          },
        )
        .subscribe();
  }

  static int calcMatch(List<String> myTags, List<String> meetingTags) {
    if (myTags.isEmpty || meetingTags.isEmpty) return 0;
    final matches = myTags.where((t) => meetingTags.contains(t)).length;
    return ((matches / meetingTags.length) * 100).round().clamp(0, 100);
  }
}
