import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:WACCA/menu_screen.dart';
import 'package:WACCA/friends_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp();

    // Sign in using existing test account
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'integration_test_user@example.com',
      password: 'password',
    );
  });

  testWidgets('FriendsScreen navigation and functionality with real auth', (WidgetTester tester) async {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    // Start with MenuScreen like the first test
    await tester.pumpWidget(MaterialApp(
      home: MenuScreen(userId: uid),
    ));

    await tester.pumpAndSettle();

    // Navigate to Friends screen
    await tester.tap(find.text('Friends'));
    await tester.pumpAndSettle();

    // Verify FriendsScreen loaded
    expect(find.byType(FriendsScreen), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);

    // Test the tabs functionality
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.mail_outline), findsWidgets);

    // Navigate to Find Friends tab
    await tester.tap(find.text('Find Friends'));
    await tester.pumpAndSettle();

    // Test search functionality
    final searchField = find.byType(TextField);
    if (searchField.evaluate().isNotEmpty) {
      await tester.tap(searchField);
      await tester.pumpAndSettle();
      await tester.enterText(searchField, 'test');
      await tester.pumpAndSettle();

      // Wait a bit for search results to load
      await tester.pump(Duration(seconds: 2));

      // Check if search was performed (results may vary)
      print('Search completed for: test');
    }

    // Navigate to My Friends tab
    await tester.tap(find.text('My Friends'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.people_outline), findsWidgets);
  });
}