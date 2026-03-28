import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/soft_symbols.dart';
import '../widgets/bloomy_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  final _pages = [
    const _OnboardPage(emoji: SoftSymbols.blossom, title: 'Your safe space', desc: 'Bloomy is a cozy corner just for you — to feel, express, and grow at your own pace.', color: AppColors.softPink),
    const _OnboardPage(emoji: SoftSymbols.ribbon, title: 'Journal your heart', desc: 'Write freely in your private diary. Track your moods and your cycle — all in one place.', color: AppColors.lavender),
    const _OnboardPage(emoji: SoftSymbols.star, title: 'Connect & inspire', desc: 'Share posts, pin your dreams, and join a community that truly gets you.', color: AppColors.beige, isLast: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.cream, AppColors.lavenderLight],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.all(20), child: BloomyLogo(size: 50)),
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: _pages.length,
                  itemBuilder: (_, i) => _pages[i],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page ? AppColors.deepPink : AppColors.softPink,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_page < _pages.length - 1) {
                            _pageCtrl.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                          } else {
                            Navigator.pushNamed(context, '/signup');
                          }
                        },
                        child: Text(
                          _page < _pages.length - 1
                              ? 'Next'
                              : "Let's bloom ${SoftSymbols.blossom}",
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      child: const Text('Already have an account? Sign in', style: TextStyle(color: AppColors.textMed)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final String emoji, title, desc;
  final Color color;
  final bool isLast;
  const _OnboardPage({required this.emoji, required this.title, required this.desc, required this.color, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140, height: 140,
              decoration: BoxDecoration(color: color.withOpacity(0.3), shape: BoxShape.circle),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 64))),
            ),
            const SizedBox(height: 40),
            Text(title, style: Theme.of(context).textTheme.displayMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text(desc, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textMed), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
