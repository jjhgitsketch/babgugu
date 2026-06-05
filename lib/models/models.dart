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
      );
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
      };
}

enum MeetingType { restaurant, delivery }

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
