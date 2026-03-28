import 'package:flutter/material.dart';

import '../screens/auth_screens.dart';
import '../screens/home_screen.dart';
import '../screens/dm_inbox_screen.dart';
import '../screens/dm_thread_screen.dart';
import '../screens/hashtag_posts_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/pin_detail_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/splash_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
  static const notifications = '/notifications';
  static const dms = '/dms';

  static String post(String postId) => '/post/$postId';
  static String pin(String pinId) => '/pin/$pinId';
  static String profile(String userId) => '/profile/$userId';
  static String chat(String chatId) => '/dms/$chatId';
  static String hashtag(String tag) => '/hashtag/$tag';
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? AppRoutes.splash;
    final uri = Uri.parse(name);

    switch (uri.path) {
      case AppRoutes.splash:
        return _material(settings, const SplashScreen());
      case AppRoutes.onboarding:
        return _material(settings, const OnboardingScreen());
      case AppRoutes.login:
        return _material(settings, const LoginScreen());
      case AppRoutes.signup:
        return _material(settings, const SignupScreen());
      case AppRoutes.home:
        return _material(settings, const HomeScreen());
      case AppRoutes.notifications:
        return _material(settings, const NotificationsScreen());
      case AppRoutes.dms:
        return _material(settings, const DmInboxScreen());
    }

    final directRoute = _routeFromPathSegments(uri.pathSegments);
    if (directRoute != null) {
      return _material(settings, directRoute);
    }

    return _material(settings, const SplashScreen());
  }

  static String? routeFromUri(Uri uri) {
    final normalized = _normalizeDeepLinkSegments(uri);
    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.first == 'post' && normalized.length >= 2) {
      return AppRoutes.post(normalized[1]);
    }

    if (normalized.first == 'pin' && normalized.length >= 2) {
      return AppRoutes.pin(normalized[1]);
    }

    if (normalized.first == 'profile' && normalized.length >= 2) {
      return AppRoutes.profile(normalized[1]);
    }

    if (normalized.first == 'notifications') {
      return AppRoutes.notifications;
    }

    if (normalized.first == 'dms') {
      if (normalized.length >= 2) {
        return AppRoutes.chat(normalized[1]);
      }
      return AppRoutes.dms;
    }

    if (normalized.first == 'hashtag' && normalized.length >= 2) {
      return AppRoutes.hashtag(normalized[1]);
    }

    return null;
  }

  static Widget? _routeFromPathSegments(List<String> segments) {
    if (segments.length >= 2 && segments[0] == 'post') {
      return PostDetailScreen(postId: segments[1]);
    }

    if (segments.length >= 2 && segments[0] == 'pin') {
      return PinDetailByIdScreen(pinId: segments[1]);
    }

    if (segments.length >= 2 && segments[0] == 'profile') {
      return OtherUserProfileScreen(userId: segments[1]);
    }

    if (segments.length == 1 && segments[0] == 'dms') {
      return const DmInboxScreen();
    }

    if (segments.length >= 2 && segments[0] == 'dms') {
      return DmThreadScreen(chatId: segments[1]);
    }

    if (segments.length >= 2 && segments[0] == 'hashtag') {
      return HashtagPostsScreen(hashtag: segments[1]);
    }

    return null;
  }

  static Route<dynamic> _material(RouteSettings settings, Widget child) {
    return MaterialPageRoute<void>(
      builder: (_) => child,
      settings: settings,
    );
  }

  static List<String> _normalizeDeepLinkSegments(Uri uri) {
    final segments = <String>[];
    final isUniversalLink = uri.scheme == 'https' || uri.scheme == 'http';
    if (!isUniversalLink && uri.host.isNotEmpty && uri.host != 'app') {
      segments.add(uri.host);
    }
    segments.addAll(uri.pathSegments.where((segment) => segment.isNotEmpty));

    if (segments.isEmpty) {
      if (uri.queryParameters.containsKey('postId')) {
        final postId = uri.queryParameters['postId']!;
        return ['post', postId];
      }
      if (uri.queryParameters.containsKey('pinId')) {
        final pinId = uri.queryParameters['pinId']!;
        return ['pin', pinId];
      }
      if (uri.queryParameters.containsKey('userId')) {
        final userId = uri.queryParameters['userId']!;
        return ['profile', userId];
      }
    }

    return segments;
  }
}
