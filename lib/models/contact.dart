import 'package:cloud_firestore/cloud_firestore.dart';

class Contact {
  const Contact({
    required this.peerId,
    required this.conversationId,
    required this.displayName,
    required this.photoUrl,
    required this.status,
    this.acceptedAt,
  });

  final String peerId;
  final String conversationId;
  final String displayName;
  final String photoUrl;
  final String status;
  final DateTime? acceptedAt;

  factory Contact.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final profile = Map<String, dynamic>.from(
      data['peerProfile'] as Map? ?? const {},
    );
    final acceptedAt = data['acceptedAt'];
    return Contact(
      peerId: data['peerId'] as String? ?? document.id,
      conversationId: data['conversationId'] as String? ?? '',
      displayName: profile['displayName'] as String? ?? 'HayChat User',
      photoUrl: profile['photoUrl'] as String? ?? '',
      status: profile['status'] as String? ?? 'HayChat contact',
      acceptedAt: acceptedAt is Timestamp ? acceptedAt.toDate() : null,
    );
  }

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'HC';
    if (parts.length == 1) {
      final word = parts.first;
      return word.substring(0, word.length.clamp(1, 2)).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
