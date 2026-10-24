import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Bottom bar with the order total on the left and the main action on the
/// right. Use it as a `Scaffold.bottomNavigationBar` so it stays on screen.
class StickyTotalBar extends StatelessWidget {
  const StickyTotalBar({
    super.key,
    required this.totalInr,
    required this.buttonLabel,
    required this.onPressed,
    this.busy = false,
    this.caption,
  });

  final int totalInr;
  final String buttonLabel;

  /// `null` disables the button.
  final VoidCallback? onPressed;

  /// Shows a spinner in the button and ignores taps.
  final bool busy;

  /// Small line under "Total", e.g. "3 items".
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.background,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(caption == null ? 'Total' : 'Total · $caption', style: textTheme.bodySmall),
                  Text('₹$totalInr', style: textTheme.titleLarge),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onPressed,
                  child: busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                        )
                      : Text(buttonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
