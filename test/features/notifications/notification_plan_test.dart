import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/constants/copy.dart';
import 'package:moodbite/core/theme.dart';
import 'package:moodbite/features/notifications/meal_notifications_tile.dart';
import 'package:moodbite/features/notifications/notification_plan.dart';
import 'package:moodbite/features/notifications/notification_service.dart';

class FakeNotificationService implements NotificationService {
  FakeNotificationService({
    this.enableResult = EnableResult.enabled,
    this.enabled = false,
    this.testResult = SendResult.sent,
  });

  final EnableResult enableResult;
  final SendResult testResult;
  int testCalls = 0;
  bool enabled;
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<EnableResult> enable() async {
    enableCalls++;
    enabled = enableResult == EnableResult.enabled;
    return enableResult;
  }

  @override
  Future<void> disable() async {
    disableCalls++;
    enabled = false;
  }

  @override
  Future<SendResult> sendTest() async {
    testCalls++;
    return testResult;
  }

  @override
  Future<void> refreshIfEnabled() async {}
}

void main() {
  final morning = DateTime(2026, 10, 20, 6);

  group('NotificationPlanner', () {
    test('never plans more than 2 notifications on a day', () {
      final plan = NotificationPlanner.plan(morning, days: 30);
      final perDay = <String, int>{};
      for (final item in plan) {
        final at = item.scheduledFor;
        perDay.update('${at.year}-${at.month}-${at.day}', (n) => n + 1, ifAbsent: () => 1);
      }
      expect(perDay.values.every((n) => n <= NotificationPlanner.maxPerDay), isTrue);
      expect(perDay, hasLength(30));
    });

    test('uses only the 08:30, 13:00 and 20:00 slots, none in quiet hours', () {
      final plan = NotificationPlanner.plan(morning);
      for (final item in plan) {
        final at = item.scheduledFor;
        expect(['8:30', '13:0', '20:0'], contains('${at.hour}:${at.minute}'));
        expect(NotificationPlanner.isQuietTime(at.hour, at.minute), isFalse);
      }
    });

    test('all three meals appear within three days', () {
      final slots = NotificationPlanner.plan(morning, days: 3).map((n) => n.slot).toSet();
      expect(slots, MealSlot.values.toSet());
    });

    test('quiet hours run from 22:00 to 07:00', () {
      expect(NotificationPlanner.isQuietTime(22, 0), isTrue);
      expect(NotificationPlanner.isQuietTime(23, 59), isTrue);
      expect(NotificationPlanner.isQuietTime(0, 0), isTrue);
      expect(NotificationPlanner.isQuietTime(6, 59), isTrue);
      expect(NotificationPlanner.isQuietTime(7, 0), isFalse);
      expect(NotificationPlanner.isQuietTime(21, 59), isFalse);
    });

    test('slots that have already passed today are skipped', () {
      final lateEvening = DateTime(2026, 10, 20, 21, 30);
      final plan = NotificationPlanner.plan(lateEvening, days: 1);
      expect(plan, isEmpty);

      final afternoon = DateTime(2026, 10, 20, 14);
      for (final item in NotificationPlanner.plan(afternoon, days: 1)) {
        expect(item.scheduledFor.isAfter(afternoon), isTrue);
      }
    });

    test('ids are unique and the plan is the same when planned twice', () {
      final first = NotificationPlanner.plan(morning, days: 14);
      final second = NotificationPlanner.plan(morning, days: 14);
      expect(first.map((n) => n.id).toSet(), hasLength(first.length));
      expect(first.map((n) => n.id).toList(), second.map((n) => n.id).toList());
      expect(first.map((n) => n.copy.title).toList(), second.map((n) => n.copy.title).toList());
    });

    test('copy always comes from the original lines in copy.dart', () {
      final allowed = {
        ...AppCopy.flirtyNotifications,
        ...AppCopy.breakfastNotifications,
        ...AppCopy.lunchNotifications,
        ...AppCopy.dinnerNotifications,
      };
      for (final item in NotificationPlanner.plan(morning, days: 14)) {
        expect(allowed, contains(item.copy));
      }
    });

    test('a plan made later the same day keeps the same ids and copy for the same slot', () {
      final early = {for (final n in NotificationPlanner.plan(morning, days: 3)) n.id: n.copy};
      final later = NotificationPlanner.plan(DateTime(2026, 10, 20, 12), days: 3);
      for (final n in later) {
        expect(early[n.id], n.copy);
      }
    });
  });

  group('MealNotificationsTile', () {
    Widget host(FakeNotificationService service) => ProviderScope(
          overrides: [notificationServiceProvider.overrideWithValue(service)],
          child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: MealNotificationsTile())),
        );

    testWidgets('starts off and does not ask for permission on its own', (tester) async {
      final service = FakeNotificationService();
      await tester.pumpWidget(host(service));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
      expect(service.enableCalls, 0);
    });

    testWidgets('turning it on enables reminders', (tester) async {
      final service = FakeNotificationService();
      await tester.pumpWidget(host(service));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(service.enableCalls, 1);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
    });

    testWidgets('a denied permission leaves the switch off and explains why', (tester) async {
      final service = FakeNotificationService(enableResult: EnableResult.permissionDenied);
      await tester.pumpWidget(host(service));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
      expect(find.text(MealNotificationsTile.permissionDeniedMessage), findsOneWidget);
    });

    testWidgets('a scheduling failure shows a friendly message', (tester) async {
      final service = FakeNotificationService(enableResult: EnableResult.failed);
      await tester.pumpWidget(host(service));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text(MealNotificationsTile.failedMessage), findsOneWidget);
    });

    testWidgets('the test tile is labelled and sends one notification without changing the opt-in', (tester) async {
      final service = FakeNotificationService();
      await tester.pumpWidget(host(service));
      await tester.pumpAndSettle();
      expect(find.text('Send test notification'), findsOneWidget);
      await tester.tap(find.text('Send test notification'));
      await tester.pumpAndSettle();
      expect(service.testCalls, 1);
      expect(service.enableCalls, 0);
      expect(find.text(MealNotificationsTile.testSentMessage), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
    });

    testWidgets('a denied permission on the test shows a friendly message', (tester) async {
      final service = FakeNotificationService(testResult: SendResult.permissionDenied);
      await tester.pumpWidget(host(service));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send test notification'));
      await tester.pumpAndSettle();
      expect(find.text(MealNotificationsTile.permissionDeniedMessage), findsOneWidget);
      expect(find.text(MealNotificationsTile.testSentMessage), findsNothing);
    });

    testWidgets('a failure on the test shows a friendly message', (tester) async {
      final service = FakeNotificationService(testResult: SendResult.failed);
      await tester.pumpWidget(host(service));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send test notification'));
      await tester.pumpAndSettle();
      expect(find.text(MealNotificationsTile.testFailedMessage), findsOneWidget);
    });

    testWidgets('an opted-in user sees the switch on and can turn it off', (tester) async {
      final service = FakeNotificationService(enabled: true);
      await tester.pumpWidget(host(service));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(service.disableCalls, 1);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
    });
  });
}
