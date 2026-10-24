import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'notification_plan.dart';
import 'notification_service.dart';

/// Opt-in switch for meal-time reminders. The notification permission is asked
/// for here, when the user turns the switch on, never at launch.
class MealNotificationsTile extends ConsumerStatefulWidget {
  const MealNotificationsTile({super.key});

  static const permissionDeniedMessage =
      'Notifications are blocked for MoodBite. Allow them in your phone settings to get reminders.';
  static const failedMessage = 'Could not set up reminders. Please try again.';
  static const testSentMessage = 'Test notification sent. Check your notification shade.';
  static const testFailedMessage = 'Could not send a test notification. Please try again.';

  @override
  ConsumerState<MealNotificationsTile> createState() => _MealNotificationsTileState();
}

class _MealNotificationsTileState extends ConsumerState<MealNotificationsTile> {
  bool _enabled = false;
  bool _busy = true;
  String? _message;
  String? _testMessage;
  bool _testError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await ref.read(notificationServiceProvider).isEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _busy = false;
    });
  }

  Future<void> _toggle(bool value) async {
    final service = ref.read(notificationServiceProvider);
    setState(() {
      _busy = true;
      _message = null;
    });
    var enabled = false;
    String? message;
    if (value) {
      switch (await service.enable()) {
        case EnableResult.enabled:
          enabled = true;
        case EnableResult.permissionDenied:
          message = MealNotificationsTile.permissionDeniedMessage;
        case EnableResult.failed:
          message = MealNotificationsTile.failedMessage;
      }
    } else {
      await service.disable();
    }
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _message = message;
      _busy = false;
    });
  }

  Future<void> _sendTest() async {
    setState(() {
      _busy = true;
      _testMessage = null;
    });
    final result = await ref.read(notificationServiceProvider).sendTest();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _testError = result != SendResult.sent;
      _testMessage = switch (result) {
        SendResult.sent => MealNotificationsTile.testSentMessage,
        SendResult.permissionDenied => MealNotificationsTile.permissionDeniedMessage,
        SendResult.failed => MealNotificationsTile.testFailedMessage,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('Meal-time reminders'),
          subtitle: const Text(
            'Up to ${NotificationPlanner.maxPerDay} a day, around 8:30 am, 1:00 pm and 8:00 pm. '
            'Quiet from 10 pm to 7 am.',
          ),
          value: _enabled,
          onChanged: _busy ? null : _toggle,
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(_message!, style: textTheme.bodySmall?.copyWith(color: AppColors.error)),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notification_add_outlined),
          title: const Text('Send test notification'),
          subtitle: const Text('Shows one reminder right now, so you can check they work.'),
          enabled: !_busy,
          onTap: _busy ? null : _sendTest,
        ),
        if (_testMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              _testMessage!,
              style: textTheme.bodySmall?.copyWith(color: _testError ? AppColors.error : AppColors.success),
            ),
          ),
      ],
    );
  }
}
