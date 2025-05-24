import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:WACCA/menu_screen.dart';
import 'package:WACCA/planner_screen.dart';

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

  testWidgets('TripPlannerScreen navigation and functionality with real auth', (WidgetTester tester) async {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    // Start with MenuScreen
    await tester.pumpWidget(MaterialApp(
      home: MenuScreen(userId: uid),
    ));

    await tester.pumpAndSettle();

    // Navigate to Trip Planner screen
    await tester.tap(find.text('Trip Planner'));
    await tester.pumpAndSettle();

    // Verify TripPlannerScreen loaded
    expect(find.byType(TripPlannerScreen), findsOneWidget);
    expect(find.text('Trip Planner'), findsOneWidget);

    // Test the tabs functionality - verify both tabs exist
    expect(find.text('My Trips'), findsOneWidget);
    expect(find.text('Invites'), findsOneWidget);

    // Test Invites tab
    await tester.tap(find.text('Invites'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.mail_outline), findsWidgets);

    // Navigate back to My Trips tab
    await tester.tap(find.text('My Trips'));
    await tester.pumpAndSettle();

    // Check if there are existing trips or empty state
    final emptyStateMessage = find.text('No trips planned yet');
    final tripCards = find.byType(Card);

    if (emptyStateMessage.evaluate().isNotEmpty) {
      print('No existing trips found - showing empty state');
      expect(find.text('Tap the + button to create your first trip'), findsOneWidget);
    } else if (tripCards.evaluate().isNotEmpty) {
      print('Found existing trips');

      // Test long press functionality on first trip card
      await tester.longPress(tripCards.first);
      await tester.pumpAndSettle();

      // Should show attractions dialog
      expect(find.text('Manage Attractions'), findsWidgets);

      // Close the dialog if it opened
      if (find.text('Close').evaluate().isNotEmpty) {
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
      }

      // Test View Participants button
      final viewParticipantsButton = find.text('View Participants');
      if (viewParticipantsButton.evaluate().isNotEmpty) {
        await tester.tap(viewParticipantsButton.first);
        await tester.pumpAndSettle();

        // Should show participants dialog
        expect(find.text('Participants'), findsWidgets);

        // Close the dialog
        if (find.text('Close').evaluate().isNotEmpty) {
          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();
        }
      }
    }

    // Test creating a new trip
    final fabButton = find.byType(FloatingActionButton);
    expect(fabButton, findsOneWidget);

    await tester.tap(fabButton);
    await tester.pumpAndSettle();

    // Verify CreateTripScreen loaded
    expect(find.byType(CreateTripScreen), findsOneWidget);
    expect(find.text('Create New Trip'), findsOneWidget);

    // Test form fields
    final tripNameField = find.widgetWithText(TextFormField, 'Trip Name');
    final destinationField = find.widgetWithText(TextFormField, 'Destination');
    final meetingPointField = find.widgetWithText(TextFormField, 'Meeting Point');

    if (tripNameField.evaluate().isNotEmpty) {
      await tester.tap(tripNameField);
      await tester.pumpAndSettle();
      await tester.enterText(tripNameField, 'Test Integration Trip');
      await tester.pumpAndSettle();
    }

    if (destinationField.evaluate().isNotEmpty) {
      await tester.tap(destinationField);
      await tester.pumpAndSettle();
      await tester.enterText(destinationField, 'Test Destination');
      await tester.pumpAndSettle();
    }

    if (meetingPointField.evaluate().isNotEmpty) {
      await tester.tap(meetingPointField);
      await tester.pumpAndSettle();
      await tester.enterText(meetingPointField, 'Test Meeting Point');
      await tester.pumpAndSettle();
    }

    // Test date picker
    final dateField = find.text('Select date');
    if (dateField.evaluate().isNotEmpty) {
      await tester.tap(dateField);
      await tester.pumpAndSettle();

      // Select a date (if date picker opens)
      final okButton = find.text('OK');
      if (okButton.evaluate().isNotEmpty) {
        await tester.tap(okButton);
        await tester.pumpAndSettle();
      }
    }

    // Test time picker
    final timeField = find.widgetWithText(TextFormField, 'Meeting Time');
    if (timeField.evaluate().isNotEmpty) {
      await tester.tap(timeField);
      await tester.pumpAndSettle();

      // Select a time (if time picker opens)
      final okButton = find.text('OK');
      if (okButton.evaluate().isNotEmpty) {
        await tester.tap(okButton);
        await tester.pumpAndSettle();
      }
    }

    // Test friend selection
    final selectFriendsButton = find.text('Select Friends to Invite');
    if (selectFriendsButton.evaluate().isNotEmpty) {
      await tester.tap(selectFriendsButton);
      await tester.pumpAndSettle();

      // Close friends dialog if opened
      final doneButton = find.text('Done');
      if (doneButton.evaluate().isNotEmpty) {
        await tester.tap(doneButton);
        await tester.pumpAndSettle();
      }
    }

    // Try to save the trip (may fail validation but tests the flow)
    final saveButton = find.text('SAVE');
    if (saveButton.evaluate().isNotEmpty) {
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      print('Trip creation attempted');
    }

    // Wait a bit for any async operations
    await tester.pump(Duration(seconds: 2));

    print('TripPlannerScreen integration test completed');
  });

  testWidgets('Trip invite functionality', (WidgetTester tester) async {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    // Navigate directly to TripPlannerScreen
    await tester.pumpWidget(MaterialApp(
      home: TripPlannerScreen(userId: uid),
    ));

    await tester.pumpAndSettle();

    // Navigate to Invites tab
    await tester.tap(find.text('Invites'));
    await tester.pumpAndSettle();

    // Check for pending invites
    final acceptButtons = find.text('Accept');
    final declineButtons = find.text('Decline');

    if (acceptButtons.evaluate().isNotEmpty) {
      print('Found pending trip invites');

      // Test accepting an invite (first one)
      await tester.tap(acceptButtons.first);
      await tester.pumpAndSettle();

      // Wait for the operation to complete
      await tester.pump(Duration(seconds: 3));

      print('Trip invite acceptance attempted');
    } else {
      print('No pending trip invites found');
      expect(find.text('No pending trip invites'), findsOneWidget);
    }

    print('Trip invite functionality test completed');
  });
}