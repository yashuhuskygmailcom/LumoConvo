import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

class FirebaseBootstrapResult {
  const FirebaseBootstrapResult._({required this.isReady, this.error});

  const FirebaseBootstrapResult.ready() : this._(isReady: true);

  const FirebaseBootstrapResult.failed(Object error)
    : this._(isReady: false, error: error);

  final bool isReady;
  final Object? error;
}

abstract final class FirebaseBootstrap {
  static Future<FirebaseBootstrapResult> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return const FirebaseBootstrapResult.ready();
    } catch (error) {
      return FirebaseBootstrapResult.failed(error);
    }
  }
}
