import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/qr_identity.dart';

class QrService {
  QrService._();

  static final QrService instance = QrService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _pointer(String uid) =>
      _firestore.collection('users').doc(uid).collection('private').doc('qr');

  Stream<QrIdentity?> watchCurrentIdentity() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _pointer(uid).snapshots().map((snapshot) {
      final token = snapshot.data()?['token'];
      return token is String && token.isNotEmpty
          ? QrIdentity(token: token)
          : null;
    });
  }

  Future<QrIdentity> ensureCurrentQr() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You are no longer signed in.');

    for (var attempt = 0; attempt < 4; attempt++) {
      final candidate = _newToken();
      try {
        final token = await _firestore.runTransaction<String>((
          transaction,
        ) async {
          final pointerReference = _pointer(user.uid);
          final pointerSnapshot = await transaction.get(pointerReference);
          final existingToken = pointerSnapshot.data()?['token'];
          if (existingToken is String && existingToken.isNotEmpty) {
            return existingToken;
          }

          final profileReference = _firestore.collection('users').doc(user.uid);
          final profileSnapshot = await transaction.get(profileReference);
          final profile = profileSnapshot.data();
          if (profile?['profileCompleted'] != true) {
            throw StateError(
              'Complete your profile before creating a QR code.',
            );
          }

          final codeReference = _firestore.collection('qrCodes').doc(candidate);
          final codeSnapshot = await transaction.get(codeReference);
          if (codeSnapshot.exists) throw const _QrCollision();

          final now = FieldValue.serverTimestamp();
          transaction.set(pointerReference, {
            'token': candidate,
            'createdAt': now,
            'updatedAt': now,
          });
          transaction.set(codeReference, {
            'ownerId': user.uid,
            'displayName': profile?['displayName'] ?? 'HayChat User',
            'photoUrl': profile?['photoUrl'] ?? '',
            'status': profile?['status'] ?? 'Hey there! I am using HayChat',
            'active': true,
            'createdAt': now,
            'updatedAt': now,
          });
          return candidate;
        });
        await syncCurrentProfile(token: token);
        return QrIdentity(token: token);
      } on _QrCollision {
        continue;
      }
    }
    throw StateError('Could not generate a unique QR code. Try again.');
  }

  Future<void> syncCurrentProfile({String? token}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final activeToken =
        token ?? (await _pointer(user.uid).get()).data()?['token'];
    if (activeToken is! String || activeToken.isEmpty) return;
    final profile = (await _firestore.collection('users').doc(user.uid).get())
        .data();
    if (profile == null) return;

    final codeReference = _firestore.collection('qrCodes').doc(activeToken);
    await _firestore.runTransaction((transaction) async {
      final codeSnapshot = await transaction.get(codeReference);
      final now = FieldValue.serverTimestamp();
      final data = <String, dynamic>{
        'ownerId': user.uid,
        'displayName': profile['displayName'] ?? 'HayChat User',
        'photoUrl': profile['photoUrl'] ?? '',
        'status': profile['status'] ?? 'Hey there! I am using HayChat',
        'active': true,
        'updatedAt': now,
      };
      if (!codeSnapshot.exists) data['createdAt'] = now;
      transaction.set(codeReference, data, SetOptions(merge: true));
    });
  }

  Future<QrProfile> resolvePayload(String payload) async {
    final token = QrIdentity.tokenFromPayload(payload);
    if (token == null) {
      throw const QrFlowException('This is not a valid HayChat QR code.');
    }
    final snapshot = await _firestore.collection('qrCodes').doc(token).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null || data['active'] != true) {
      throw const QrFlowException('This QR code is no longer active.');
    }
    return QrProfile(
      token: token,
      ownerId: data['ownerId'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'HayChat User',
      photoUrl: data['photoUrl'] as String? ?? '',
      status: data['status'] as String? ?? 'HayChat contact',
    );
  }

  String _newToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

class QrFlowException implements Exception {
  const QrFlowException(this.message);
  final String message;

  @override
  String toString() => message;
}

class _QrCollision implements Exception {
  const _QrCollision();
}
