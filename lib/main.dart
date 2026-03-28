import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'navigation/app_router.dart';
import 'theme/app_theme.dart';
import 'providers/app_provider.dart';
import 'services/deep_link_service.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? firebaseBootstrapError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (error) {
    firebaseBootstrapError = error;
    debugPrint('Firebase initialization skipped: $error');
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(BloomyApp(firebaseBootstrapError: firebaseBootstrapError));
}

class BloomyApp extends StatefulWidget {
  const BloomyApp({super.key, this.firebaseBootstrapError});

  final Object? firebaseBootstrapError;

  @override
  State<BloomyApp> createState() => _BloomyAppState();
}

class _BloomyAppState extends State<BloomyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  String? _pendingExternalRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePlatformServices();
    });
  }

  @override
  void dispose() {
    PushNotificationService.instance.dispose();
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  Future<void> _initializePlatformServices() async {
    try {
      await PushNotificationService.instance.initialize(
        scaffoldMessengerKey: _scaffoldMessengerKey,
        onNavigate: _navigateFromExternalSource,
      );

      await DeepLinkService.instance.initialize(
        onUri: (uri) {
          final routeName = AppRouter.routeFromUri(uri);
          if (routeName != null) {
            _navigateFromExternalSource(routeName);
          }
        },
      );
    } catch (error) {
      debugPrint('Failed to initialize platform services: $error');
    }
  }

  void _navigateFromExternalSource(String routeName) {
    final navState = _navigatorKey.currentState;
    if (navState == null) {
      _pendingExternalRoute = routeName;
      return;
    }

    final auth = Provider.of<AuthProvider>(navState.context, listen: false);
    if (!auth.isLoggedIn) {
      _pendingExternalRoute = routeName;
      return;
    }

    navState.pushNamed(routeName);
  }

  void _flushPendingRouteIfLoggedIn(BuildContext context) {
    if (_pendingExternalRoute == null) {
      return;
    }
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      return;
    }

    final routeToOpen = _pendingExternalRoute!;
    _pendingExternalRoute = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState?.pushNamed(routeToOpen);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.firebaseBootstrapError != null) {
      return MaterialApp(
        title: 'Bloomy',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: FirebaseConfigurationErrorScreen(
          error: widget.firebaseBootstrapError!,
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => JournalProvider()),
        ChangeNotifierProvider(create: (_) => MoodProvider()),
        ChangeNotifierProvider(create: (_) => SavedPostProvider()),
        ChangeNotifierProvider(create: (_) => PinProvider()),
        ChangeNotifierProvider(create: (_) => FollowProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => CommentProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => MediaLayoutProvider()..init()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          _flushPendingRouteIfLoggedIn(context);
          return MaterialApp(
            title: 'Bloomy',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.theme,
            navigatorKey: _navigatorKey,
            scaffoldMessengerKey: _scaffoldMessengerKey,
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRouter.onGenerateRoute,
            builder: (context, child) {
              final appChild = child ?? const SizedBox.shrink();
              if (!kIsWeb) {
                return appChild;
              }

              return Container(
                color: const Color(0xFFF0EBE7),
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 720) {
                        return appChild;
                      }

                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: ClipRect(child: appChild),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class FirebaseConfigurationErrorScreen extends StatelessWidget {
  const FirebaseConfigurationErrorScreen({
    super.key,
    required this.error,
  });

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Firebase configuration is missing for this platform.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Provide the required --dart-define values for iOS/web and restart the app.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
