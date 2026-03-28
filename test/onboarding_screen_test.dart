import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloomy/screens/onboarding_screen.dart';

void main() {
  testWidgets('Onboarding advances pages and navigates to signup', (
    WidgetTester tester,
  ) async {
    String? lastRouteName;

    await tester.pumpWidget(
      MaterialApp(
        home: const OnboardingScreen(),
        onGenerateRoute: (settings) {
          lastRouteName = settings.name;
          return MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: Center(child: Text(settings.name ?? 'unknown')),
            ),
            settings: settings,
          );
        },
      ),
    );

    expect(find.text('Your safe space'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Journal your heart'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Connect & inspire'), findsOneWidget);
    expect(find.textContaining("Let's bloom"), findsOneWidget);

    await tester.tap(find.textContaining("Let's bloom"));
    await tester.pumpAndSettle();

    expect(lastRouteName, '/signup');
    expect(find.text('/signup'), findsOneWidget);
  });

  testWidgets('Onboarding login shortcut navigates to login', (
    WidgetTester tester,
  ) async {
    String? lastRouteName;

    await tester.pumpWidget(
      MaterialApp(
        home: const OnboardingScreen(),
        onGenerateRoute: (settings) {
          lastRouteName = settings.name;
          return MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: Center(child: Text(settings.name ?? 'unknown')),
            ),
            settings: settings,
          );
        },
      ),
    );

    await tester.tap(find.text('Already have an account? Sign in'));
    await tester.pumpAndSettle();

    expect(lastRouteName, '/login');
    expect(find.text('/login'), findsOneWidget);
  });
}
