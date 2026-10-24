import 'package:flutter/material.dart';

import '../constants/copy.dart';
import '../core/theme.dart';
import 'emoji.dart';

/// Spinner with a random loading quip (picked once per load).
class LoadingView extends StatefulWidget {
  const LoadingView({super.key});

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView> {
  final _quip = AppCopy.randomQuip();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(_quip, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Friendly error with an optional retry button. Pass a message from
/// `friendlyError`, never a raw exception.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Friendly empty state (not an error).
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.emoji, required this.title, this.message});

  final String emoji;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Emoji(emoji, size: 48), // decorative: the title below says it in words
            const SizedBox(height: AppSpacing.md),
            Text(title, textAlign: TextAlign.center, style: textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(message!, textAlign: TextAlign.center, style: textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
