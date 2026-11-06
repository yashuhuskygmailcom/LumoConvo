import 'dart:async';

import 'package:flutter/material.dart';

import 'firebase_bootstrap.dart';
import 'haychat_app.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebase = await FirebaseBootstrap.initialize();
  if (firebase.isReady) {
    try {
      await NotificationService.instance.initialize();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
    }
  }
  runApp(HayChatApp(firebase: firebase));
  if (firebase.isReady) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(NotificationService.instance.processInitialMessage());
    });
  }
}
