import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationPeer {
  const ConversationPeer({
    required this.id,
    required this.displayName,
    required this.photoUrl,
    this.avatarBytes,
  });

  final String id;
  final String displayName;
  final String photoUrl;
  final Uint8List? avatarBytes;

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

class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    required this.name,
    required this.creatorId,
    required this.memberIds,
    required this.memberProfiles,
    required this.lastMessage,
    required this.lastMessageType,
    required this.lastSenderId,
    required this.unreadCounts,
    this.updatedAt,
  });

  final String id;
  final String type;
  final String name;
  final String creatorId;
  final List<String> memberIds;
  final Map<String, Map<String, dynamic>> memberProfiles;
  final String lastMessage;
  final String lastMessageType;
  final String lastSenderId;
  final Map<String, int> unreadCounts;
  final DateTime? updatedAt;

  factory Conversation.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final rawProfiles =
        data['memberProfiles'] as Map<String, dynamic>? ?? const {};
    final rawUnread = data['unreadCounts'] as Map<String, dynamic>? ?? const {};
    final updatedAt = data['updatedAt'];
    return Conversation(
      id: document.id,
      type: data['type'] as String? ?? 'direct',
      name: data['name'] as String? ?? '',
      creatorId: data['creatorId'] as String? ?? '',
      memberIds: List<String>.from(data['memberIds'] as List? ?? const []),
      memberProfiles: rawProfiles.map(
        (key, value) =>
            MapEntry(key, Map<String, dynamic>.from(value as Map? ?? const {})),
      ),
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageType: data['lastMessageType'] as String? ?? 'text',
      lastSenderId: data['lastSenderId'] as String? ?? '',
      unreadCounts: rawUnread.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }

  ConversationPeer peerFor(String currentUserId) {
    final peerId = memberIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => currentUserId,
    );
    final profile = memberProfiles[peerId] ?? const {};
    return ConversationPeer(
      id: peerId,
      displayName: profile['displayName'] as String? ?? 'HayChat User',
      photoUrl: profile['photoUrl'] as String? ?? '',
    );
  }

  bool get isGroup => type == 'group';

  ConversationPeer presentationFor(String currentUserId) {
    if (isGroup) {
      return ConversationPeer(id: '', displayName: name, photoUrl: '');
    }
    return peerFor(currentUserId);
  }

  int unreadFor(String userId) => unreadCounts[userId] ?? 0;
}

class ChatRouteArguments {
  const ChatRouteArguments({required this.conversationId, required this.peer});

  final String conversationId;
  final ConversationPeer peer;
}
