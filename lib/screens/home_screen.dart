import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';
import 'mood_tab.dart';
import 'feed_screen.dart';
import 'journal_screen.dart';
import 'pins_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'study_module_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      final auth = context.read<AuthProvider>();
      final user = auth.user;
      if (user == null) {
        return;
      }

      await context.read<PostProvider>().reloadFeed(reset: true);
      await context.read<PinProvider>().reloadPublicPins(reset: true);
      await context.read<PinProvider>().loadUserPins(user.id, reset: true);
      await context.read<PinProvider>().loadUserBoards(user.id);
      await context.read<UserProvider>().refresh();
      await context.read<JournalProvider>().init(user.id);
      await context.read<MoodProvider>().init(user.id);
      await context.read<NotificationProvider>().loadNotifications(user.id);
      await context.read<ChatProvider>().init(user.id);
    });
  }

  final _screens = const [
    FeedScreen(),
    PinsScreen(),
    SearchScreen(),
    StudyModuleScreen(),
    MoodScreen(),
    JournalScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: IndexedStack(index: _idx, children: _screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            boxShadow: [BoxShadow(color: AppColors.lavender.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, -5))],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BottomNavigationBar(
              currentIndex: _idx,
              onTap: (i) => setState(() => _idx = i),
              type: BottomNavigationBarType.shifting,
              backgroundColor: AppColors.white,
              selectedItemColor: AppColors.deepPink,
              unselectedItemColor: AppColors.textLight,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
              unselectedLabelStyle: const TextStyle(fontSize: 10),
              elevation: 0,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.push_pin_outlined), activeIcon: Icon(Icons.push_pin_rounded), label: 'Pins'),
                BottomNavigationBarItem(icon: Icon(Icons.search_rounded), activeIcon: Icon(Icons.search_rounded), label: 'Discover'),
                BottomNavigationBarItem(icon: Icon(Icons.school_outlined), activeIcon: Icon(Icons.school_rounded), label: 'Study'),
                BottomNavigationBarItem(icon: Icon(Icons.favorite_border_rounded), activeIcon: Icon(Icons.favorite_rounded), label: 'Mood'),
                BottomNavigationBarItem(icon: Icon(Icons.book_outlined), activeIcon: Icon(Icons.book_rounded), label: 'Journal'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'Me'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
