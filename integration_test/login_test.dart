import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:WACCA/auth_screens.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('Login screen form interaction and validation', (WidgetTester tester) async {
    // Build LoginScreen widget
    await tester.pumpWidget(MaterialApp(
      home: LoginScreen(onShowSignUp: () {}),
    ));

    // Ensure UI is rendered
    expect(find.text('VacationCatcher'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);

    // Tap login without filling inputs — expect validation
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);

    // Enter invalid email and valid password
    await tester.enterText(find.byType(TextFormField).at(0), 'invalid-email');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email'), findsOneWidget);

    // Enter valid email and password
    await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');

    await tester.tap(find.text('Login'));
    await tester.pump(); // Allow UI to update (loading indicator)

    // Simulate waiting for async auth
    await tester.pumpAndSettle();

    // Expect button still there (UI didn't crash)
    expect(find.text('Login'), findsOneWidget);
  });
}
