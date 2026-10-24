import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'features/auth/google_sign_in_service.dart';
import 'features/notifications/notification_service.dart';
import 'widgets/startup_error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final Env env;
  try {
    env = await Env.load();
    await Supabase.initialize(
      url: env.supabaseUrl,
      publishableKey: env.supabaseAnonKey,
    );
  } on EnvException catch (e) {
    runApp(StartupErrorApp(message: e.message));
    return;
  } catch (_) {
    runApp(const StartupErrorApp(
      message: 'Could not connect to the backend. Check SUPABASE_URL in .env.',
    ));
    return;
  }
  // Reminders are optional: if set-up fails the app starts without them.
  NotificationService? notifications;
  try {
    final service = await LocalNotificationService.create();
    await service.refreshIfEnabled();
    notifications = service;
  } catch (_) {
    notifications = null;
  }
  // Screens show their own "Try again" button, so automatic retries are off.
  runApp(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      googleWebClientIdProvider.overrideWithValue(env.googleWebClientId),
      if (notifications != null) notificationServiceProvider.overrideWithValue(notifications),
    ],
    child: const MoodBiteApp(),
  ));
}

class MoodBiteApp extends ConsumerWidget {
  const MoodBiteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'MoodBite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
