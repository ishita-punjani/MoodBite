import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../constants/copy.dart';
import 'notification_plan.dart';

enum EnableResult { enabled, permissionDenied, failed }

enum SendResult { sent, permissionDenied, failed }

/// Meal-time notifications behind an interface, so the profile toggle can be
/// tested without the plugin.
abstract class NotificationService {
  /// Whether the user opted in.
  Future<bool> isEnabled();

  /// Asks for the Android 13+ permission, then schedules. Called only from the
  /// profile toggle, never at launch.
  Future<EnableResult> enable();

  Future<void> disable();

  /// Shows one notification right now, using the app's own copy, so the user
  /// can check reminders work. Asks for the permission first if needed. Does
  /// not change the opt-in or the schedule.
  Future<SendResult> sendTest();

  /// Re-plans the rolling window if the user opted in. Safe to call at start-up.
  Future<void> refreshIfEnabled();
}

class LocalNotificationService implements NotificationService {
  LocalNotificationService(this._plugin, this._prefs);

  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferences _prefs;

  static const _enabledKey = 'meal_notifications_enabled';

  /// Outside the planner's id range (day number x 10 + slot), so a test never
  /// replaces a scheduled reminder.
  static const _testNotificationId = 1;
  static const _channel = AndroidNotificationDetails(
    'meal_reminders',
    'Meal reminders',
    channelDescription: 'Breakfast, lunch and dinner nudges',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  /// Time zone and plugin set-up. Does not ask for any permission.
  static Future<LocalNotificationService> create() async {
    tz_data.initializeTimeZones();
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    return LocalNotificationService(plugin, await SharedPreferences.getInstance());
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> isEnabled() async => _prefs.getBool(_enabledKey) ?? false;

  @override
  Future<EnableResult> enable() async {
    try {
      final granted = await _android?.requestNotificationsPermission() ?? true;
      if (!granted) return EnableResult.permissionDenied;
      await _schedule();
      await _prefs.setBool(_enabledKey, true);
      return EnableResult.enabled;
    } on Exception {
      return EnableResult.failed;
    }
  }

  @override
  Future<void> disable() async {
    await _prefs.setBool(_enabledKey, false);
    await _plugin.cancelAllPendingNotifications();
  }

  @override
  Future<SendResult> sendTest() async {
    try {
      final granted = await _android?.requestNotificationsPermission() ?? true;
      if (!granted) return SendResult.permissionDenied;
      final copy = AppCopy.pick(AppCopy.flirtyNotifications);
      await _plugin.show(
        id: _testNotificationId,
        title: copy.title,
        body: copy.body,
        notificationDetails: const NotificationDetails(android: _channel),
      );
      return SendResult.sent;
    } on Exception {
      return SendResult.failed;
    }
  }

  @override
  Future<void> refreshIfEnabled() async {
    if (!await isEnabled()) return;
    try {
      // Without the permission nothing would be shown, so turn the opt-in off
      // and let the user switch it on again from the profile screen.
      if (await _android?.areNotificationsEnabled() == false) {
        await disable();
        return;
      }
      await _schedule();
    } on Exception {
      // Reminders are optional; a scheduling problem must never stop the app.
    }
  }

  Future<void> _schedule() async {
    final kolkata = tz.getLocation('Asia/Kolkata');
    await _plugin.cancelAllPendingNotifications();
    for (final item in NotificationPlanner.plan(tz.TZDateTime.now(kolkata))) {
      final at = item.scheduledFor;
      await _plugin.zonedSchedule(
        id: item.id,
        title: item.copy.title,
        body: item.copy.body,
        scheduledDate: tz.TZDateTime(kolkata, at.year, at.month, at.day, at.hour, at.minute),
        notificationDetails: const NotificationDetails(android: _channel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}

/// Overridden in `main()` with the real service. The default does nothing, so
/// tests and widgets never touch the plugin by accident.
final notificationServiceProvider = Provider<NotificationService>((ref) => const _NoNotifications());

class _NoNotifications implements NotificationService {
  const _NoNotifications();

  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<EnableResult> enable() async => EnableResult.failed;

  @override
  Future<void> disable() async {}

  @override
  Future<SendResult> sendTest() async => SendResult.failed;

  @override
  Future<void> refreshIfEnabled() async {}
}
