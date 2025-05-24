import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:WACCA/menu_screen.dart';
import 'package:WACCA/shared_albums/screen.dart';
import 'package:WACCA/shared_albums/create_shared_album.dart';

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

  testWidgets('SharedAlbumsScreen navigation and functionality with real auth', (WidgetTester tester) async {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    // Start with MenuScreen
    await tester.pumpWidget(MaterialApp(
      home: MenuScreen(userId: uid),
    ));

    await tester.pumpAndSettle();

    // Navigate to Shared Albums screen
    await tester.tap(find.text('Shared Albums'));
    await tester.pumpAndSettle();

    // Verify SharedAlbumsScreen loaded
    expect(find.byType(SharedAlbumsScreen), findsOneWidget);
    expect(find.text('Shared Albums'), findsOneWidget);

    // Test the tabs
    expect(find.text('Created by Me'), findsOneWidget);
    expect(find.text('Shared with Me'), findsOneWidget);

    // Test "Created by Me" tab (should be default)
    await tester.pumpAndSettle(Duration(seconds: 2)); // Wait for data to load

    // Look for empty state or albums
    final hasAlbums = find.byType(GridView).evaluate().isNotEmpty;
    if (!hasAlbums) {
      // Check for empty state
      expect(find.text('No albums created yet'), findsOneWidget);
      expect(find.byIcon(Icons.photo_album_outlined), findsOneWidget);
    }

    // Test action buttons (only visible on "Created by Me" tab)
    expect(find.byIcon(Icons.add), findsOneWidget); // Create album button
    expect(find.byIcon(Icons.delete), findsOneWidget); // Delete album button

    // Test Create Album button navigation
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.byType(CreateSharedAlbumScreen), findsOneWidget);

    // Go back to SharedAlbumsScreen
    Navigator.of(tester.element(find.byType(CreateSharedAlbumScreen))).pop();
    await tester.pumpAndSettle();

    // Test Delete Album button (should show dialog)
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    // Verify delete dialog appears
    expect(find.text('Delete Album'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Cancel the delete dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Switch to "Shared with Me" tab
    await tester.tap(find.text('Shared with Me'));
    await tester.pumpAndSettle(Duration(seconds: 2)); // Wait for data to load

    // Verify we're on the "Shared with Me" tab
    // Action buttons should not be visible on this tab
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);

    // Look for empty state or shared albums
    final hasSharedAlbums = find.byType(GridView).evaluate().isNotEmpty;
    if (!hasSharedAlbums) {
      // Check for empty state
      expect(find.text('No albums shared with you'), findsOneWidget);
      expect(find.byIcon(Icons.photo_album_outlined), findsOneWidget);
    }

    // Switch back to "Created by Me" tab to verify tab functionality
    await tester.tap(find.text('Created by Me'));
    await tester.pumpAndSettle();

    // Verify action buttons are visible again
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);
  });
}