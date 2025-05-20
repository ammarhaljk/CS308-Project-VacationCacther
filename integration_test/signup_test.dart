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

  testWidgets('Sign up form interaction and validation', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SignUpScreen(onShowLogin: () {}),
    ));

    expect(find.text('VacationCatcher'), findsOneWidget);
    expect(find.text('Create a new account'), findsOneWidget);

    // Tap Sign Up without filling fields
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a username'), findsOneWidget);
    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter a password'), findsOneWidget);
    expect(find.text('Please confirm your password'), findsOneWidget);

    // Fill invalid username and short password
    await tester.enterText(find.byType(TextFormField).at(0), 'ab'); // username
    await tester.enterText(find.byType(TextFormField).at(1), 'invalid-email'); // email
    await tester.enterText(find.byType(TextFormField).at(2), '123'); // password
    await tester.enterText(find.byType(TextFormField).at(3), '456'); // confirm

    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();

    expect(find.text('Username must be at least 3 characters'), findsOneWidget);
    expect(find.text('Please enter a valid email'), findsOneWidget);
    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);

    // Enter valid values
    await tester.enterText(find.byType(TextFormField).at(0), 'testuser');
    await tester.enterText(find.byType(TextFormField).at(1), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.enterText(find.byType(TextFormField).at(3), 'password123');

    await tester.tap(find.text('Sign Up'));
    await tester.pump(); // Start loading

    // Allow for async logic and UI updates
    await tester.pumpAndSettle();

    expect(find.text('Sign Up'), findsOneWidget);
  });
}
