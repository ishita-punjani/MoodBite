import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/mood.dart';
import '../../widgets/emoji.dart';
import '../../widgets/recommendation_card.dart';
import '../../widgets/state_views.dart';
import '../browse/catalogue_repository.dart';
import 'home_controllers.dart';
import 'recommendation_logic.dart';
import 'recommendation_repository.dart';

class RecommendationsScreen extends ConsumerWidget {
  const RecommendationsScreen({super.key, required this.moodId});

  final String moodId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = ref.watch(deliveryZoneProvider);
    final filters = ref.watch(recommendationFiltersProvider);
    final moods = ref.watch(moodsProvider);

    final mood = switch (moods) {
      AsyncData(:final value) => value.where((m) => m.id == moodId).firstOrNull,
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(title: Text(mood == null ? 'Your picks' : '${mood.label} picks')),
      body: zone == null
          ? const EmptyView(
              emoji: '📍',
              title: 'Choose a delivery area first',
              message: 'Go back and pick your area in Mumbai.',
            )
          : _Results(
              request: RecommendationRequest(
                moodId: moodId,
                location: zone.centre,
                maxPriceInr: filters.maxPriceInr,
                diet: filters.diet,
              ),
              mood: mood,
              areaName: zone.name,
            ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.request, required this.mood, required this.areaName});

  final RecommendationRequest request;
  final Mood? mood;
  final String areaName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(recommendationsProvider(request));
    return results.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        message: friendlyError(e),
        onRetry: () => ref.invalidate(recommendationsProvider(request)),
      ),
      data: (result) {
        final list = result.picks;
        if (list.isEmpty) {
          final price = request.maxPriceInr;
          return _EmptyResults(
            title: price == null ? 'Nothing matches right now' : 'Nothing under ₹$price for this mood',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _MoodSwitcher(currentMoodId: request.moodId),
            const SizedBox(height: AppSpacing.sm),
            Text('Distances are from the centre of $areaName.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            for (final rec in list) ...[
              RecommendationCard(
                rec: rec,
                source: result.source,
                moodId: request.moodId,
                reason: mood == null ? rec.reason : rec.reason ?? templateReason(rec, mood!),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            const _TryAnotherMoodButton(),
          ],
        );
      },
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        EmptyView(
          emoji: '🍽️',
          title: title,
          message: 'Try a higher price, change the food preference, or pick another mood.',
        ),
        const _TryAnotherMoodButton(),
      ],
    );
  }
}

class _TryAnotherMoodButton extends StatelessWidget {
  const _TryAnotherMoodButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => context.go(AppRoutes.home),
      icon: const Icon(Icons.mood),
      label: const Text('Try another mood'),
    );
  }
}

/// Row of mood chips: tapping another mood swaps the results straight away.
class _MoodSwitcher extends ConsumerWidget {
  const _MoodSwitcher({required this.currentMoodId});

  final String currentMoodId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moods = ref.watch(moodsProvider).asData?.value ?? const <Mood>[];
    if (moods.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: kMinTouchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: moods.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final mood = moods[index];
          return ChoiceChip(
            avatar: Emoji(mood.emoji, size: 18),
            label: Text(mood.label),
            selected: mood.id == currentMoodId,
            showCheckmark: false,
            onSelected: (_) {
              if (mood.id != currentMoodId) context.pushReplacement(AppRoutes.recommendationsFor(mood.id));
            },
          );
        },
      ),
    );
  }
}
