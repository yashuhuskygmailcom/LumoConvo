import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;

  factory ChatMessage.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final createdAt = data['createdAt'];
    return ChatMessage(
      id: document.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }
}
