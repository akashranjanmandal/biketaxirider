import 'dart:io';

import 'package:aamar_captain/app/theme.dart';
import 'package:aamar_captain/data/captain_state.dart';
import 'package:aamar_captain/main.dart';
import 'package:aamar_captain/ui/captain_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Walks the whole captain app in light and dark mode, and on a small phone
/// with large text, failing on any exception (overflow, null error, …).
/// Ride timing runs on the test's fake clock, so the vehicle really drives
/// to the pickup and the drop.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();
  // the map's tile cache asks the OS for a cache folder
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (_) async => Directory.systemTemp.path,
  );

  Future<void> step(WidgetTester t, [int ms = 1000]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapText(WidgetTester t, String text, {int wait = 800}) async {
    final f = find.text(text).last;
    await t.ensureVisible(f);
    await t.pump();
    await t.tap(f);
    await step(t, wait);
  }

  Future<void> swipe(WidgetTester t, String label) async {
    final f = find.ancestor(of: find.text(label), matching: find.byType(SlideToConfirm));
    expect(f, findsOneWidget);
    await t.drag(f, const Offset(600, 0));
    await step(t, 1200);
  }

  final variants = [
    (name: 'light', mode: ThemeMode.light, size: const Size(1080, 2400), dpr: 2.75, text: 1.0),
    (name: 'dark', mode: ThemeMode.dark, size: const Size(1080, 2400), dpr: 2.75, text: 1.0),
    (name: 'small phone, 1.2x text', mode: ThemeMode.light, size: const Size(720, 1280), dpr: 2.0, text: 1.2),
  ];

  for (final v in variants) {
    testWidgets('full captain flow (${v.name})', (t) async {
      t.view.physicalSize = v.size;
      t.view.devicePixelRatio = v.dpr;
      t.platformDispatcher.textScaleFactorTestValue = v.text;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      themeController.mode = v.mode;
      captain.reset();

      await t.pumpWidget(const AamarCaptainApp());
      await step(t, 2500); // splash → welcome
      expect(find.text('Earn on your schedule'), findsOneWidget);
      await tapText(t, 'Continue with phone number');

      // ── phone + OTP ──
      await t.enterText(find.byType(TextField), '9876543210');
      await step(t, 300);
      await tapText(t, 'Get OTP', wait: 1500);
      expect(find.text('Enter the code'), findsOneWidget);
      await t.enterText(find.byType(TextField), '1111');
      await step(t, 1500);
      expect(find.textContaining('isn\'t right'), findsOneWidget);
      await tapText(t, 'Fill', wait: 1800);

      // ── registration ──
      expect(find.text('Personal details'), findsOneWidget);
      await tapText(t, 'Continue', wait: 400);
      expect(find.text('Enter your full name as on your licence'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, 'Rahul Das');
      await tapText(t, 'English', wait: 200);
      await tapText(t, 'Continue');
      FocusManager.instance.primaryFocus?.unfocus();

      expect(find.text('Your vehicle'), findsOneWidget);
      await tapText(t, 'Cab', wait: 500);
      await tapText(t, 'Premium', wait: 300);
      await tapText(t, 'Bike', wait: 300);
      await t.enterText(find.byType(TextField).last, 'wb 02 ak 4821');
      await step(t, 300);
      await tapText(t, 'Continue');
      FocusManager.instance.primaryFocus?.unfocus();

      expect(find.text('Documents'), findsWidgets);
      for (final doc in ['Driving licence', 'Registration certificate (RC)', 'Aadhaar card', 'PAN card', 'Vehicle photo', 'Profile selfie']) {
        await tapText(t, doc, wait: 700);
        await tapText(t, 'Capture', wait: 2600);
      }
      expect(captain.docsComplete, isTrue);
      await tapText(t, 'Continue');

      expect(find.text('Bank account'), findsWidgets);
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), '50100234567812');
      await t.enterText(fields.at(1), '50100234567812');
      await t.enterText(fields.at(2), 'hdfc0001234');
      await step(t, 300);
      expect(find.text('HDFC Bank'), findsOneWidget);
      await tapText(t, 'Continue');
      FocusManager.instance.primaryFocus?.unfocus();

      expect(find.text('Review & submit'), findsOneWidget);
      await tapText(t, 'Submit for verification', wait: 1500);
      expect(find.text('Under verification'), findsOneWidget);
      await step(t, 3500);
      expect(find.text('You\'re all set, Rahul'), findsOneWidget);
      await tapText(t, 'Start earning', wait: 1500);

      // ── home: go online, get a request ──
      expect(find.text('You\'re offline'), findsOneWidget);
      await swipe(t, 'Swipe to go online');
      expect(find.text('You\'re online'), findsOneWidget);
      await step(t, 9000);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Koustav Das'), findsOneWidget);
      await tapText(t, 'Accept', wait: 1500);
      expect(find.text('Picking up Koustav'), findsOneWidget);
      await tapText(t, 'Navigate', wait: 600);
      await tapText(t, 'Message', wait: 800);
      await tapText(t, 'On my way', wait: 1600);
      await t.tapAt(const Offset(20, 40)); // close the sheet
      await step(t, 800);

      // drive to the pickup (wall-clock based, on the fake clock)
      await step(t, 27000);
      expect(find.text('Waiting for Koustav'), findsOneWidget);
      await t.tap(find.byType(TextField).last);
      await t.enterText(find.byType(TextField).last, '1111');
      await step(t, 1400);
      expect(find.textContaining('Wrong PIN'), findsOneWidget);
      await tapText(t, 'Fill', wait: 1500);
      FocusManager.instance.primaryFocus?.unfocus();
      expect(find.text('Dropping Koustav'), findsOneWidget);

      // trip, then end it
      await step(t, 6000);
      await swipe(t, 'Swipe to end trip');
      expect(find.text('COLLECT CASH'), findsOneWidget);
      await tapText(t, 'Cash collected', wait: 1500);

      // summary: rate the rider
      expect(find.text('Trip complete'), findsOneWidget);
      await t.tap(find.byIcon(Symbols.star).at(4));
      await step(t, 500);
      await tapText(t, 'Polite', wait: 200);
      await tapText(t, 'Submit rating', wait: 1500);
      expect(find.text('You\'re online'), findsOneWidget);
      expect(captain.trips.first.riderStars, 5);

      // next request: let it run out
      await step(t, 11000);
      expect(find.text('Accept'), findsOneWidget);
      await step(t, 16000);
      expect(find.text('Missed request'), findsOneWidget);
      await step(t, 3000);
      await swipe(t, 'Swipe to go offline');
      expect(find.text('You\'re offline'), findsOneWidget);

      // ── tabs ──
      await tapText(t, 'Earnings');
      await tapText(t, 'Week', wait: 600);
      await tapText(t, 'Month', wait: 600);
      await tapText(t, 'Withdraw', wait: 800);
      await tapText(t, 'All', wait: 300);
      final withdraw = find.textContaining('Withdraw ₹');
      if (withdraw.evaluate().isNotEmpty) {
        await t.tap(withdraw.last);
        await step(t, 1800);
        expect(find.textContaining('is on its way'), findsOneWidget);
        await tapText(t, 'Done');
      } else {
        await t.tapAt(const Offset(20, 40));
        await step(t, 800);
      }
      await tapText(t, 'Payouts', wait: 900);
      expect(find.text('Payout history'), findsOneWidget);
      await t.pageBack();
      await step(t, 900);

      await tapText(t, 'Rides');
      await tapText(t, 'Cancelled', wait: 400);
      await tapText(t, 'Completed', wait: 400);
      await tapText(t, 'All', wait: 400);
      await t.tap(find.textContaining('Victoria Memorial').first);
      await step(t, 900);
      expect(find.text('Report issue'), findsOneWidget);
      await t.tapAt(const Offset(20, 40));
      await step(t, 800);

      await tapText(t, 'Account');
      await tapText(t, 'Vehicle & documents', wait: 900);
      expect(find.text('Pollution certificate (PUC)'), findsOneWidget);
      await t.pageBack();
      await step(t, 900);
      await tapText(t, 'Notifications', wait: 900);
      await t.pageBack();
      await step(t, 900);
      await tapText(t, 'Help', wait: 900);
      await tapText(t, 'When do I get paid?', wait: 400);
      await t.pageBack();
      await step(t, 900);
      await tapText(t, 'Safety', wait: 900);
      await t.pageBack();
      await step(t, 900);
      await tapText(t, 'Dark', wait: 600);
      await tapText(t, 'Light', wait: 600);
      themeController.mode = v.mode;
      await step(t, 600);
      await tapText(t, 'Home');
      expect(find.text('You\'re offline'), findsOneWidget);

      // log out
      await tapText(t, 'Account');
      await tapText(t, 'Log out', wait: 800);
      await tapText(t, 'Log out', wait: 1200);
      expect(find.text('Continue with phone number'), findsOneWidget);

      await t.pumpWidget(const SizedBox());
      captain.reset();
      await step(t, 2500);
    });
  }
}
