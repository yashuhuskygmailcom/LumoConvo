import 'package:cloud_firestore/cloud_firestore.dart';

class ContactInvite {
  const ContactInvite({
    required this.senderId,
    required this.recipientId,
    required this.qrToken,
    required this.status,
    required this.senderName,
    required this.senderPhotoUrl,
    required this.senderStatus,
    required this.recipientName,
    required this.recipientPhotoUrl,
    required this.recipientStatus,
    this.createdAt,
    this.conversationId,
  });

  final String senderId;
  final String recipientId;
  final String qrToken;
  final String status;
  final String senderName;
  final String senderPhotoUrl;
  final String senderStatus;
  final String recipientName;
  final String recipientPhotoUrl;
  final String recipientStatus;
  final DateTime? createdAt;
  final String? conversationId;

  factory ContactInvite.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final sender = Map<String, dynamic>.from(
      data['senderProfile'] as Map? ?? const {},
    );
    final recipient = Map<String, dynamic>.from(
      data['recipientProfile'] as Map? ?? const {},
    );
    final createdAt = data['createdAt'];
    return ContactInvite(
      senderId: data['senderId'] as String? ?? document.id,
      recipientId: data['recipientId'] as String? ?? '',
      qrToken: data['qrToken'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      senderName: sender['displayName'] as String? ?? 'HayChat User',
      senderPhotoUrl: sender['photoUrl'] as String? ?? '',
      senderStatus: sender['status'] as String? ?? 'HayChat contact',
      recipientName: recipient['displayName'] as String? ?? 'HayChat User',
      recipientPhotoUrl: recipient['photoUrl'] as String? ?? '',
      recipientStatus: recipient['status'] as String? ?? 'HayChat contact',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      conversationId: data['conversationId'] as String?,
    );
  }
}
