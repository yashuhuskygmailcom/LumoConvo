import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'notification_service.dart';
import 'preferences_service.dart';
import 'qr_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

  Stream<User?> get userChanges => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw const AuthFlowException('Could not create the account.');
    }
    await user.sendEmailVerification();
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signInWithGoogle() async {
    if (!_googleInitialized) {
      await _googleSignIn.initialize();
      _googleInitialized = true;
    }

    final googleUser = await _googleSignIn.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw const AuthFlowException(
        'Google did not return a valid identity token.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _auth.signInWithCredential(credential);
  }

  Future<User?> refreshCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed != null && refreshed.emailVerified) {
      await refreshed.getIdTokenResult(true);
    }
    return refreshed;
  }

  Future<bool> hasVerifiedEmailToken(User user) async {
    if (!user.emailVerified) return false;
    final token = await user.getIdTokenResult(true);
    return token.claims?['email_verified'] == true;
  }

  Future<void> ensureCurrentProfile() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFlowException('You are not signed in.');
    await _ensureProfile(user);
    final profile = await _firestore.collection('users').doc(user.uid).get();
    if (profile.data()?['profileCompleted'] == true) {
      await QrService.instance.ensureCurrentQr();
    }
    await setPresence(isOnline: true);
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFlowException('You are not signed in.');
    if (user.emailVerified) return;
    await user.sendEmailVerification();
  }

  Future<void> signOut() async {
    await NotificationService.instance.unregisterCurrentDevice().catchError((
      _,
    ) {
      // Signing out must still succeed if token cleanup is temporarily offline.
    });
    await setPresence(isOnline: false).catchError((_) {});
    await Future.wait([
      _auth.signOut(),
      if (_googleInitialized) _googleSignIn.signOut(),
    ]);
  }

  Future<void> setPresence({required bool isOnline}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    var visibleOnline = isOnline;
    if (isOnline) {
      final preferences = await PreferencesService.instance.getCurrent();
      visibleOnline = preferences.showOnlineStatus;
    }
    await _firestore.collection('users').doc(user.uid).set({
      'isOnline': visibleOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _ensureProfile(User user) async {
    final reference = _firestore.collection('users').doc(user.uid);
    final snapshot = await reference.get(
      const GetOptions(source: Source.server),
    );
    final existing = snapshot.data();
    final existingName = existing?['displayName'];
    final existingPhoto = existing?['photoUrl'];
    final existingStatus = existing?['status'];
    final existingCompleted = existing?['profileCompleted'];
    final fallbackName = user.email?.split('@').first ?? 'HayChat User';
    final authDisplayName = user.displayName?.trim();
    final displayName = authDisplayName != null && authDisplayName.isNotEmpty
        ? authDisplayName
        : existingName is String && existingName.trim().isNotEmpty
        ? existingName.trim()
        : fallbackName;
    await reference.set({
      'uid': user.uid,
      'displayName': displayName,
      if (snapshot.exists) 'email': FieldValue.delete(),
      if (snapshot.exists) 'displayNameLower': FieldValue.delete(),
      'photoUrl': existingPhoto is String ? existingPhoto : user.photoURL ?? '',
      'status': existingStatus is String && existingStatus.trim().isNotEmpty
          ? existingStatus
          : 'Hey there! I am using HayChat',
      'profileCompleted': existingCompleted is bool ? existingCompleted : false,
      if (!snapshot.exists) 'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
      if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String messageFor(Object error) {
    if (error is AuthFlowException) return error.message;
    if (error is GoogleSignInException) {
      return switch (error.code) {
        GoogleSignInExceptionCode.canceled => 'Google sign-in was cancelled.',
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Google sign-in is not configured for this app yet. Check the Firebase OAuth setup.',
        GoogleSignInExceptionCode.interrupted =>
          'Google sign-in was interrupted. Please try again.',
        GoogleSignInExceptionCode.uiUnavailable =>
          'Google sign-in cannot open right now. Please try again.',
        _ => 'Google sign-in failed. Please try again.',
      };
    }
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'Enter a valid email address.',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'The email or password is incorrect.',
        'email-already-in-use' => 'An account already uses this email.',
        'weak-password' =>
          'Use a stronger password with at least 6 characters.',
        'too-many-requests' => 'Too many attempts. Please wait and try again.',
        'network-request-failed' =>
          'Check your internet connection and try again.',
        'operation-not-allowed' =>
          'Enable this sign-in method in Firebase Authentication.',
        'account-exists-with-different-credential' =>
          'This email already uses a different sign-in method.',
        _ => error.message ?? 'Authentication failed. Please try again.',
      };
    }
    return 'Something went wrong. Please try again.';
  }
}

class AuthFlowException implements Exception {
  const AuthFlowException(this.message);
  final String message;

  @override
  String toString() => message;
}
