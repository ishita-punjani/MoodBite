import 'package:flutter/material.dart';

import '../../constants/copy.dart';
import '../../core/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('MoodBite', style: textTheme.headlineSmall?.copyWith(color: AppColors.primary)),
          const SizedBox(height: AppSpacing.sm),
          Text('Mood-based food ordering for Mumbai. Academic mini project.', style: textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          const _Notice(title: 'Demo data', body: AppCopy.demoDataNotice),
          const _Notice(
            title: AppCopy.demoDeliveryLabel,
            body: 'There is no real delivery partner. Order tracking is simulated for demonstration only.',
          ),
          const _Notice(
            title: 'Map data',
            body: 'Restaurant locations and maps use OpenStreetMap data, (c) OpenStreetMap contributors.',
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(body),
          ],
        ),
      ),
    );
  }
}
