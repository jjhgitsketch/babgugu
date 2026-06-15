// lib/models/models.dart

class UserModel {
  final String id;
  final String name;
  final List<String> tags;
  final int age;
  final String? nickname;
  final String? avatarUrl;
  final String? university;
  final String? department;
  final String? studentId;
  final String? gender;
  final String? schoolEmail;
  final bool studentVerified;
  final DateTime? studentVerifiedAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.tags,
    required this.age,
    this.nickname,
    this.avatarUrl,
    this.university,
    this.department,
    this.studentId,
    this.gender,
    this.schoolEmail,
    this.studentVerified = false,
    this.studentVerifiedAt,
  });

  String get displayName => nickname?.isNotEmpty == true ? nickname! : name;

  UserModel copyWith({
    String? name,
    List<String>? tags,
    int? age,
    String? nickname,
    String? avatarUrl,
    String? university,
    String? department,
    String? studentId,
    String? gender,
    String? schoolEmail,
    bool? studentVerified,
    DateTime? studentVerifiedAt,
  }) =>
      UserModel(
        id: id,
        name: name ?? this.name,
        tags: tags ?? this.tags,
        age: age ?? this.age,
        nickname: nickname ?? this.nickname,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        university: university ?? this.university,
        department: department ?? this.department,
        studentId: studentId ?? this.studentId,
        gender: gender ?? this.gender,
        schoolEmail: schoolEmail ?? this.schoolEmail,
        studentVerified: studentVerified ?? this.studentVerified,
        studentVerifiedAt: studentVerifiedAt ?? this.studentVerifiedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tags': tags,
        'age': age,
        if (nickname != null) 'nickname': nickname,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (university != null) 'university': university,
        if (department != null) 'department': department,
        if (studentId != null) 'student_id': studentId,
        if (gender != null) 'gender': gender,
        if (schoolEmail != null) 'school_email': schoolEmail,
        'student_verified': studentVerified,
        if (studentVerifiedAt != null)
          'student_verified_at': studentVerifiedAt!.toIso8601String(),
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        tags: List<String>.from(json['tags'] ?? []),
        age: json['age'] as int? ?? 20,
        nickname: json['nickname'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        university: json['university'] as String?,
        department: json['department'] as String?,
        studentId: json['student_id'] as String?,
        gender: json['gender'] as String?,
        schoolEmail: json['school_email'] as String?,
        studentVerified: json['student_verified'] as bool? ?? false,
        studentVerifiedAt: json['student_verified_at'] == null
            ? null
            : DateTime.parse(json['student_verified_at'] as String),
      );
}

class TrustScore {
  final double average;
  final int count;

  const TrustScore({required this.average, required this.count});

  bool get hasReviews => count > 0;
  String get display => hasReviews ? average.toStringAsFixed(1) : '-';

  static const empty = TrustScore(average: 0, count: 0);
}

class SoloPlaceScore {
  final double average;
  final int count;

  const SoloPlaceScore({required this.average, required this.count});

  bool get hasReviews => count > 0;
  String get display => average.toStringAsFixed(1);
}

class SoloPlaceReviewDraft {
  final int score;
  final List<String> tags;
  final String comment;

  const SoloPlaceReviewDraft({
    required this.score,
    required this.tags,
    required this.comment,
  });
}

class MeetingModel {
  final String id;
  final String title;
  final String description;
  final MeetingType type;
  final List<String> tags;
  final int maxMembers;
  final int currentMembers;
  final bool hasDutchPay;
  final String location;
  final String hostId;
  final String hostName;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final String? category;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? imageUrl;
  final String? baeminTogetherUrl;
  MeetingStatus status;
  int matchPercent;
  bool isJoined;

  MeetingModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.tags,
    required this.maxMembers,
    required this.currentMembers,
    required this.hasDutchPay,
    required this.location,
    required this.hostId,
    required this.hostName,
    required this.createdAt,
    this.scheduledAt,
    this.category,
    this.latitude,
    this.longitude,
    this.address,
    this.imageUrl,
    this.baeminTogetherUrl,
    this.status = MeetingStatus.open,
    this.matchPercent = 0,
    this.isJoined = false,
  });

  bool get hasLocation => latitude != null && longitude != null;
  DateTime get meetingTime => scheduledAt ?? createdAt;

  factory MeetingModel.fromJson(Map<String, dynamic> json) => MeetingModel(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        type: json['type'] == 'delivery'
            ? MeetingType.delivery
            : MeetingType.restaurant,
        tags: List<String>.from(json['tags'] ?? []),
        maxMembers: json['max_members'] as int,
        currentMembers: json['current_members'] as int? ?? 1,
        hasDutchPay: json['has_dutch_pay'] as bool? ?? false,
        location: json['location'] as String? ?? '',
        hostId: json['host_id'] as String? ?? '',
        hostName: json['host_name'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
        scheduledAt: json['scheduled_at'] == null
            ? null
            : DateTime.parse(json['scheduled_at'] as String),
        category: json['category'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        address: json['address'] as String?,
        imageUrl: json['image_url'] as String?,
        baeminTogetherUrl: json['baemin_together_url'] as String?,
        status: MeetingStatusX.fromDb(json['status'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'type': type == MeetingType.delivery ? 'delivery' : 'restaurant',
        'tags': tags,
        'max_members': maxMembers,
        'current_members': currentMembers,
        'has_dutch_pay': hasDutchPay,
        'location': location,
        'host_id': hostId,
        'host_name': hostName,
        if (scheduledAt != null) 'scheduled_at': scheduledAt!.toIso8601String(),
        if (category != null) 'category': category,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (address != null) 'address': address,
        if (imageUrl != null) 'image_url': imageUrl,
        if (baeminTogetherUrl != null) 'baemin_together_url': baeminTogetherUrl,
        'status': status.dbValue,
      };
}

enum MeetingType { restaurant, delivery }

enum MeetingStatus { open, started, completed }

extension MeetingStatusX on MeetingStatus {
  String get dbValue {
    switch (this) {
      case MeetingStatus.open:
        return 'open';
      case MeetingStatus.started:
        return 'started';
      case MeetingStatus.completed:
        return 'completed';
    }
  }

  String get label {
    switch (this) {
      case MeetingStatus.open:
        return '모집 중';
      case MeetingStatus.started:
        return '모임 진행 중';
      case MeetingStatus.completed:
        return '모임 완료';
    }
  }

  bool get isJoinable => this == MeetingStatus.open;

  static MeetingStatus fromDb(String? value) {
    switch (value) {
      case 'started':
        return MeetingStatus.started;
      case 'completed':
        return MeetingStatus.completed;
      case 'open':
      default:
        return MeetingStatus.open;
    }
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime time;
  final bool isMe;
  final MessageType type;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.time,
    required this.isMe,
    this.type = MessageType.text,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, String myId) =>
      ChatMessage(
        id: json['id'] as String,
        senderId: json['sender_id'] as String? ?? '',
        senderName: json['sender_name'] as String? ?? '',
        text: json['text'] as String,
        time: DateTime.parse(json['created_at'] as String).toLocal(),
        isMe: json['sender_id'] == myId,
        type: json['type'] == 'dutchPay'
            ? MessageType.dutchPay
            : json['type'] == 'system'
                ? MessageType.system
                : MessageType.text,
      );
}

enum MessageType { text, dutchPay, system }

UserModel? currentUser;

const List<String> allTags = [
  '#코딩',
  '#운동',
  '#조용히식사',
  '#한식파',
  '#일식파',
  '#중식파',
  '#양식파',
  '#채식',
  '#매운거좋아',
  '#독서',
  '#영화',
  '#게임',
  '#음악',
  '#여행',
  '#사진',
  '#카페',
  '#혼밥',
  '#새벽형',
  '#저녁형',
  '#대화좋아',
  '#조용한모임',
  '#대학생',
  '#직장인',
];
