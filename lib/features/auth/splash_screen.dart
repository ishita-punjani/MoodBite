import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/state_views.dart';
import 'auth_repository.dart';
import 'session_controller.dart';

/// Shown while the profile loads after sign-in, or if loading it failed.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: session,
          builder: (context, _) {
            if (session.status != SessionStatus.error) {
              return const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BrandLogo(size: 120),
                  SizedBox(height: AppSpacing.sm),
                  LoadingView(),
                ],
              );
            }
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const BrandLogo(size: 96),
                ErrorView(
                  message: session.errorMessage ?? 'Could not load your profile.',
                  onRetry: session.loadProfile,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => ref.read(authRepositoryProvider).signOut().catchError((_) {}),
                  child: const Text('Sign out'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
