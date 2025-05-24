import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:WACCA/menu_screen.dart';
import 'package:WACCA/shared_albums/screen.dart';
import 'package:WACCA/planner_screen.dart';
import 'package:WACCA/friends_screen.dart';
import 'package:WACCA/main.dart';

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

  testWidgets('Menu screen UI and navigation with real auth', (WidgetTester tester) async {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    await tester.pumpWidget(MaterialApp(
      home: MenuScreen(userId: uid),
    ));

    await tester.pumpAndSettle();

    // Verify main screen UI
    expect(find.text('VacationCatcher'), findsNWidgets(2));
    expect(find.text('Capture and share your memorable moments'), findsOneWidget);

    // Navigate to "Your Albums"
    await tester.tap(find.text('Your Albums'));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(AlbumScreen))).pop();
    await tester.pumpAndSettle();

    // Navigate to "Shared Albums"
    await tester.tap(find.text('Shared Albums'));
    await tester.pumpAndSettle();
    expect(find.byType(SharedAlbumsScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(SharedAlbumsScreen))).pop();
    await tester.pumpAndSettle();

    // Navigate to "Friends"
    await tester.tap(find.text('Friends'));
    await tester.pumpAndSettle();
    expect(find.byType(FriendsScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(FriendsScreen))).pop();
    await tester.pumpAndSettle();

    // Navigate to "Trip Planner"
    await tester.tap(find.text('Trip Planner'));
    await tester.pumpAndSettle();
    expect(find.byType(TripPlannerScreen), findsOneWidget);
  });
}
