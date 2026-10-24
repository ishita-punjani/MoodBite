import '../../constants/copy.dart';

/// The three meal-time reminders (CLAUDE.md section 10), in Asia/Kolkata time.
enum MealSlot {
  breakfast(8, 30),
  lunch(13, 0),
  dinner(20, 0);

  const MealSlot(this.hour, this.minute);

  final int hour;
  final int minute;

  List<NotificationCopy> get mealLines => switch (this) {
        MealSlot.breakfast => AppCopy.breakfastNotifications,
        MealSlot.lunch => AppCopy.lunchNotifications,
        MealSlot.dinner => AppCopy.dinnerNotifications,
      };
}

/// One notification to schedule. [scheduledFor] holds Asia/Kolkata wall-clock
/// fields (year to minute); the scheduler turns it into a `TZDateTime`.
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.scheduledFor,
    required this.slot,
    required this.copy,
  });

  final int id;
  final DateTime scheduledFor;
  final MealSlot slot;
  final NotificationCopy copy;
}

/// Decides which notifications to schedule. Pure and deterministic, so the
/// daily cap, quiet hours and copy rotation can be unit tested.
abstract final class NotificationPlanner {
  /// At most this many notifications per calendar day.
  static const maxPerDay = 2;

  /// How many days ahead are scheduled. The app re-plans each time it starts.
  static const horizonDays = 7;

  /// Nothing is shown from [quietStartHour] until [quietEndHour] the next morning.
  static const quietStartHour = 22;
  static const quietEndHour = 7;

  static bool isQuietTime(int hour, int minute) =>
      hour >= quietStartHour || hour < quietEndHour;

  /// Notifications for the next [days] days, starting after [now]
  /// (Asia/Kolkata wall-clock). Each day gets the meal slots outside quiet
  /// hours, with one slot skipped in rotation so the cap of [maxPerDay]
  /// still lets all three meals appear over a few days.
  static List<PlannedNotification> plan(DateTime now, {int days = horizonDays}) {
    final planned = <PlannedNotification>[];
    for (var offset = 0; offset < days; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      final dayNumber = DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;
      final skipped = MealSlot.values[dayNumber % MealSlot.values.length];
      final slots = MealSlot.values
          .where((slot) => slot != skipped && !isQuietTime(slot.hour, slot.minute))
          .take(maxPerDay);
      for (final slot in slots) {
        final at = DateTime(day.year, day.month, day.day, slot.hour, slot.minute);
        if (!at.isAfter(now)) continue;
        planned.add(PlannedNotification(
          id: dayNumber * 10 + slot.index,
          scheduledFor: at,
          slot: slot,
          copy: _copyFor(slot, dayNumber),
        ));
      }
    }
    return planned;
  }

  /// Meal-specific line on even days, a flirty line on odd days.
  static NotificationCopy _copyFor(MealSlot slot, int dayNumber) {
    final pool = dayNumber.isEven ? slot.mealLines : AppCopy.flirtyNotifications;
    return pool[(dayNumber ~/ 2 + slot.index) % pool.length];
  }
}
