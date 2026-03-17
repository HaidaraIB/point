import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  String id;
  String senderId;
  String? text;
  String? image;
  DateTime createdAt;
  bool seen;
  MessageModel({
    required this.id,
    required this.senderId,
    this.text,
    this.image,
    required this.createdAt,
    this.seen = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json, String id) {
    return MessageModel(
      id: id,
      senderId: json['senderId'],
      text: json['text'],
      image: json['image'],
      createdAt:
          json['createdAt'] != null
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
      seen: json['seen'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'text': text,
      'image': image,
      'createdAt': createdAt,
      'seen': seen,
    };
  }
}

class ChatModel {
  String id;
  List<String> members; // employee IDs
  bool isGroup;
  String? groupName;
  String? department;
  DateTime createdAt;
  ChatModel({
    required this.id,
    required this.members,
    required this.isGroup,
    this.groupName,
    this.department,
    required this.createdAt,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json, String id) {
    return ChatModel(
      id: id,
      members: List<String>.from(json['members'] ?? []),
      isGroup: json['isGroup'] ?? false,
      groupName: json['groupName'],
      department: json['department'],
      createdAt:
          json['createdAt'] != null
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'members': members,
      'isGroup': isGroup,
      'groupName': groupName,
      'department': department,
      'createdAt': createdAt,
    };
  }
}
