import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/bloomy_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6, curve: Curves.easeIn)));
    _scale = Tween<double>(begin: 0.7, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.6, curve: Curves.elasticOut)));
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    await auth.init();
    if (!mounted) return;

    final userProv = context.read<UserProvider>();
    final pinProv = context.read<PinProvider>();
    final postProv = context.read<PostProvider>();
    final journalProv = context.read<JournalProvider>();
    final moodProv = context.read<MoodProvider>();
    final notificationProv = context.read<NotificationProvider>();
    final chatProv = context.read<ChatProvider>();

    if (auth.user != null) {
      final userId = auth.user!.id;
      await userProv.init();
      await pinProv.init();
      await postProv.init();
      await journalProv.init(userId);
      await moodProv.init(userId);
      await pinProv.loadUserPins(userId);
      await pinProv.loadUserBoards(userId);
      await notificationProv.loadNotifications(userId);
      await chatProv.init(userId);
    } else {
      await journalProv.clearSession();
      await moodProv.clearSession();
      await notificationProv.clearSession();
      await chatProv.clearSession();
    }

    await context.read<SavedPostProvider>().init();

    if (!mounted) return;
    if (auth.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.cream, AppColors.lavenderLight, AppColors.softPink],
            stops: [0, 0.5, 1],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: const BloomyLogo(size: 100, showTagline: true),
            ),
          ),
        ),
      ),
    );
  }
}
