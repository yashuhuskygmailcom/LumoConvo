import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_preferences.dart';

class PreferencesService {
  PreferencesService._();

  static final PreferencesService instance = PreferencesService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _reference(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('private')
      .doc('settings');

  Stream<UserPreferences> watchCurrent() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(const UserPreferences());
    return _reference(
      uid,
    ).snapshots().map((snapshot) => UserPreferences.fromMap(snapshot.data()));
  }

  Future<UserPreferences> getCurrent() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const UserPreferences();
    final snapshot = await _reference(uid).get();
    return UserPreferences.fromMap(snapshot.data());
  }

  Future<void> save(UserPreferences preferences) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No authenticated user.');
    await _reference(
      uid,
    ).set({...preferences.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
  }
}
