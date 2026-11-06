import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import 'qr_service.dart';

class CurrentUserProfileState {
  const CurrentUserProfileState({
    required this.profile,
    required this.hasPendingWrites,
    required this.isFromCache,
  });

  final AppUser? profile;
  final bool hasPendingWrites;
  final bool isFromCache;
}

class UserService {
  UserService._();

  static final UserService instance = UserService._();
  static const maximumAvatarBytes = 350 * 1024;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Stream<AppUser?> watchUser(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.exists ? AppUser.fromDocument(snapshot) : null,
        );
  }

  Stream<CurrentUserProfileState> watchCurrentUserState(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => CurrentUserProfileState(
            profile: snapshot.exists ? AppUser.fromDocument(snapshot) : null,
            hasPendingWrites: snapshot.metadata.hasPendingWrites,
            isFromCache: snapshot.metadata.isFromCache,
          ),
        );
  }

  Future<AppUser> getCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No authenticated user.');
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!snapshot.exists) throw StateError('User profile is missing.');
    return AppUser.fromDocument(snapshot);
  }

  Future<void> completeProfile({
    required String displayName,
    required String status,
    Uint8List? avatarBytes,
    bool removeAvatar = false,
  }) {
    return _saveProfile(
      displayName: displayName,
      status: status,
      avatarBytes: avatarBytes,
      removeAvatar: removeAvatar,
      markComplete: true,
    );
  }

  Future<void> updateProfile({
    required String displayName,
    required String status,
    Uint8List? avatarBytes,
    bool removeAvatar = false,
  }) {
    return _saveProfile(
      displayName: displayName,
      status: status,
      avatarBytes: avatarBytes,
      removeAvatar: removeAvatar,
      markComplete: false,
    );
  }

  Future<void> _saveProfile({
    required String displayName,
    required String status,
    required bool markComplete,
    Uint8List? avatarBytes,
    bool removeAvatar = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No authenticated user.');
    final cleanName = displayName.trim();
    final cleanStatus = status.trim();
    if (cleanName.length < 2 || cleanName.length > 40) {
      throw ArgumentError('Display name must be 2–40 characters.');
    }
    if (cleanStatus.isEmpty || cleanStatus.length > 120) {
      throw ArgumentError('About must be 1–120 characters.');
    }
    if (avatarBytes != null && avatarBytes.length > maximumAvatarBytes) {
      throw ArgumentError('Profile picture is too large.');
    }

    final values = <String, dynamic>{
      'uid': user.uid,
      'displayName': cleanName,
      'status': cleanStatus,
      'email': FieldValue.delete(),
      'displayNameLower': FieldValue.delete(),
      if (markComplete) 'profileCompleted': true,
      if (markComplete) 'isOnline': true,
      if (markComplete) 'lastSeen': FieldValue.serverTimestamp(),
      if (avatarBytes != null) 'avatarBytes': Blob(avatarBytes),
      if (avatarBytes != null) 'photoUrl': '',
      if (removeAvatar) 'avatarBytes': FieldValue.delete(),
      if (removeAvatar) 'photoUrl': '',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(values, SetOptions(merge: true));
    await user.updateDisplayName(cleanName);
    await QrService.instance.ensureCurrentQr();
  }
}
