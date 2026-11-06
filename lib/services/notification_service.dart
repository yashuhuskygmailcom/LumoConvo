import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import '../models/conversation.dart';
import '../routes.dart';
import 'preferences_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'haychat_messages',
    'HayChat messages',
    description: 'New direct and group chat messages.',
    importance: Importance.high,
  );

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  RemoteMessage? _initialMessage;
  String? _registeredToken;
  String? _registeredUid;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _initializeLocalNotifications();

    FirebaseMessaging.onMessage.listen(
      _showForegroundMessage,
      onError: _reportError,
    );
    FirebaseMessaging.onMessageOpenedApp.listen(
      _openMessage,
      onError: _reportError,
    );
    _messaging.onTokenRefresh.listen(_replaceToken, onError: _reportError);
    _initialMessage = await _messaging.getInitialMessage();
    FirebaseAuth.instance.userChanges().listen((user) {
      if (user == null) {
        _registeredUid = null;
        _registeredToken = null;
        return;
      }
      unawaited(_registerCurrentDevice(user.uid));
    }, onError: _reportError);
  }

  Future<void> processInitialMessage() async {
    final message = _initialMessage;
    _initialMessage = null;
    if (message == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _openMessage(message);
  }

  Future<void> unregisterCurrentDevice() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = _registeredToken ?? await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _messagingReference(user.uid).set({
      'tokens': FieldValue.arrayRemove([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _registeredToken = null;
    _registeredUid = null;
  }

  Future<void> _initializeLocalNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_haychat'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
          _openData(data);
        } catch (error, stackTrace) {
          _reportError(error, stackTrace);
        }
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
  }

  Future<void> _registerCurrentDevice(String uid) async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        return;
      }
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      if (_registeredUid == uid && _registeredToken == token) return;
      await _saveToken(uid, token, previousToken: _registeredToken);
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  Future<void> _replaceToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || token.isEmpty) return;
    try {
      await _saveToken(uid, token, previousToken: _registeredToken);
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  Future<void> _saveToken(
    String uid,
    String token, {
    String? previousToken,
  }) async {
    final updates = <String, dynamic>{
      'tokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _messagingReference(uid).set(updates, SetOptions(merge: true));
    if (previousToken != null && previousToken != token) {
      await _messagingReference(uid).set({
        'tokens': FieldValue.arrayRemove([previousToken]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    _registeredUid = uid;
    _registeredToken = token;
  }

  DocumentReference<Map<String, dynamic>> _messagingReference(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('private')
        .doc('messaging');
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    try {
      final preferences = await PreferencesService.instance.getCurrent();
      if (!preferences.notificationsEnabled) return;
      final notification = message.notification;
      final title = notification?.title ?? 'HayChat';
      final body = notification?.body ?? 'You have a new message.';
      await _localNotifications.show(
        id: message.messageId?.hashCode ?? message.hashCode,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            playSound: preferences.soundsEnabled,
            icon: 'ic_stat_haychat',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: preferences.soundsEnabled,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  void _openMessage(RemoteMessage message) => _openData(message.data);

  void _openData(Map<String, dynamic> data) {
    final conversationId = data['conversationId'] as String?;
    if (conversationId == null || conversationId.isEmpty) return;
    final isGroup = data['conversationType'] == 'group';
    final displayName = isGroup
        ? data['conversationName'] as String? ?? 'Group chat'
        : data['senderName'] as String? ?? 'HayChat User';
    final peer = ConversationPeer(
      id: isGroup ? '' : data['senderId'] as String? ?? '',
      displayName: displayName,
      photoUrl: isGroup ? '' : data['senderPhoto'] as String? ?? '',
    );
    navigatorKey.currentState?.pushNamed(
      HayRoutes.conversation,
      arguments: ChatRouteArguments(conversationId: conversationId, peer: peer),
    );
  }

  void _reportError(Object error, [StackTrace? stackTrace]) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stackTrace),
    );
  }
}
