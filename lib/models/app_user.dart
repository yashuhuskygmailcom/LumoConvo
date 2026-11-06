import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.photoUrl,
    required this.status,
    required this.profileCompleted,
    required this.isOnline,
    this.avatarBytes,
    this.lastSeen,
  });

  final String id;
  final String displayName;
  final String photoUrl;
  final String status;
  final bool profileCompleted;
  final bool isOnline;
  final Uint8List? avatarBytes;
  final DateTime? lastSeen;

  factory AppUser.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final lastSeen = data['lastSeen'];
    final avatar = data['avatarBytes'];
    return AppUser(
      id: document.id,
      displayName: data['displayName'] as String? ?? 'HayChat User',
      photoUrl: data['photoUrl'] as String? ?? '',
      status: data['status'] as String? ?? 'Hey there! I am using HayChat',
      profileCompleted: data['profileCompleted'] as bool? ?? false,
      isOnline: data['isOnline'] as bool? ?? false,
      avatarBytes: avatar is Blob ? avatar.bytes : null,
      lastSeen: lastSeen is Timestamp ? lastSeen.toDate() : null,
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

  Map<String, dynamic> get conversationProfile => {
    'displayName': displayName,
    'photoUrl': photoUrl,
  };
}
