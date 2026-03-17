import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
    id: json['id'],
    senderId: json['senderId'],
    receiverId: json['receiverId'],
    content: json['content'],
    timestamp: (json['timestamp'] as Timestamp).toDate(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'receiverId': receiverId,
    'content': content,
    'timestamp': timestamp,
  };
}
