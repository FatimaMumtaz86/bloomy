import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../navigation/app_router.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSubscription;

  Future<void> initialize({
    required GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
    required void Function(String routeName) onNavigate,
  }) async {
    await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    _onMessageSubscription ??= FirebaseMessaging.onMessage.listen((message) {
      _handleForegroundMessage(
        message: message,
        scaffoldMessengerKey: scaffoldMessengerKey,
        onNavigate: onNavigate,
      );
    });

    _onMessageOpenedSubscription ??=
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final routeName = _routeFromData(message.data);
      if (routeName != null) {
        onNavigate(routeName);
      }
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      final routeName = _routeFromData(initialMessage.data);
      if (routeName != null) {
        onNavigate(routeName);
      }
    }
  }

  Future<String?> getToken() => _messaging.getToken();

  Future<void> dispose() async {
    await _onMessageSubscription?.cancel();
    await _onMessageOpenedSubscription?.cancel();
    _onMessageSubscription = null;
    _onMessageOpenedSubscription = null;
  }

  void _handleForegroundMessage({
    required RemoteMessage message,
    required GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
    required void Function(String routeName) onNavigate,
  }) {
    final routeName = _routeFromData(message.data);
    final title = message.notification?.title ?? 'Bloomy notification';
    final body = message.notification?.body ?? 'Tap to view details';

    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('$title\n$body'),
        action: routeName == null
            ? null
            : SnackBarAction(
                label: 'Open',
                onPressed: () => onNavigate(routeName),
              ),
      ),
    );
  }

  String? _routeFromData(Map<String, dynamic> data) {
    final explicitRoute = data['route'] as String?;
    if (explicitRoute != null && explicitRoute.trim().isNotEmpty) {
      return explicitRoute;
    }

    final postId = data['postId'] as String?;
    if (postId != null && postId.trim().isNotEmpty) {
      return AppRoutes.post(postId);
    }

    final pinId = data['pinId'] as String?;
    if (pinId != null && pinId.trim().isNotEmpty) {
      return AppRoutes.pin(pinId);
    }

    final profileId =
        (data['profileId'] as String?) ?? (data['userId'] as String?) ?? (data['fromUserId'] as String?);
    if (profileId != null && profileId.trim().isNotEmpty) {
      return AppRoutes.profile(profileId);
    }

    return null;
  }
}
