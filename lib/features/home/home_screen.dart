import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/copy.dart';
import '../../core/errors.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/diet.dart';
import '../../models/mood.dart';
import '../../widgets/brand.dart';
import '../../widgets/emoji.dart';
import '../../widgets/state_views.dart';
import '../../widgets/user_avatar.dart';
import '../auth/session_controller.dart';
import '../browse/catalogue_repository.dart';
import 'area_picker.dart';
import 'home_controllers.dart';

/// Mood tab: greeting, delivery area, quick filters, then the mood cards.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _priceFormKey = GlobalKey<FormState>();
  late final TextEditingController _maxPrice;

  @override
  void initState() {
    super.initState();
    final filters = ref.read(recommendationFiltersProvider);
    _maxPrice = TextEditingController(text: filters.maxPriceInr?.toString() ?? '');
  }

  @override
  void dispose() {
    _maxPrice.dispose();
    super.dispose();
  }

  Future<void> _pickMood(Mood mood) async {
    if (!_priceFormKey.currentState!.validate()) return;
    ref.read(recommendationFiltersProvider.notifier).setMaxPrice(Validators.parseMaxPrice(_maxPrice.text));
    if (ref.read(deliveryZoneProvider) == null) {
      final zone = await showAreaPicker(context);
      if (zone == null || !mounted) return;
    }
    if (mounted) context.push(AppRoutes.recommendationsFor(mood.id));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final zone = ref.watch(deliveryZoneProvider);
    final filters = ref.watch(recommendationFiltersProvider);
    final moods = ref.watch(moodsProvider);
    final firstName = ref.watch(sessionControllerProvider).profile?.fullName?.trim().split(' ').first;
    final greeting = AppCopy.greetingForHour(DateTime.now().hour);

    return Scaffold(
      appBar: AppBar(title: const BrandTitle('MoodBite'), actions: const [ProfileAvatarButton()]),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            firstName == null || firstName.isEmpty ? greeting : '$greeting, $firstName',
            style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('How are you feeling?', style: textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          _DeliveryAreaRow(
            label: zone == null ? 'Choose delivery area' : 'Delivering to ${zone.name}',
            onTap: () => showAreaPicker(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Form(
            key: _priceFormKey,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                SegmentedButton<Diet>(
                  showSelectedIcon: false,
                  segments: [
                    for (final diet in Diet.values) ButtonSegment(value: diet, label: Text(diet.label)),
                  ],
                  selected: {filters.diet},
                  onSelectionChanged: (selection) =>
                      ref.read(recommendationFiltersProvider.notifier).setDiet(selection.first),
                ),
                SizedBox(
                  width: 168,
                  child: TextFormField(
                    controller: _maxPrice,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                    decoration: const InputDecoration(
                      labelText: 'Max price',
                      hintText: 'e.g. 300',
                      prefixText: '₹ ',
                      helperText: 'Optional',
                    ),
                    validator: Validators.maxPriceInr,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          moods.when(
            loading: () => const SizedBox(height: 200, child: LoadingView()),
            error: (e, _) => ErrorView(message: friendlyError(e), onRetry: () => ref.invalidate(moodsProvider)),
            data: (list) => list.isEmpty
                ? const EmptyView(emoji: '🤔', title: 'No moods yet', message: 'The menu is still being set up.')
                : _MoodGrid(moods: list, onTap: _pickMood),
          ),
        ],
      ),
    );
  }
}

class _DeliveryAreaRow extends StatelessWidget {
  const _DeliveryAreaRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label. Tap to change the area.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTouchTarget),
          child: Row(
            children: [
              const Icon(Icons.place, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
              const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two cards per row; each row is as tall as its taller card, so larger
/// system text sizes never overflow.
class _MoodGrid extends StatelessWidget {
  const _MoodGrid({required this.moods, required this.onTap});

  final List<Mood> moods;
  final ValueChanged<Mood> onTap;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < moods.length; i += 2) {
      final second = i + 1 < moods.length ? moods[i + 1] : null;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _MoodCard(mood: moods[i], onTap: onTap)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: second == null ? const SizedBox() : _MoodCard(mood: second, onTap: onTap)),
            ],
          ),
        ),
      );
      rows.add(const SizedBox(height: AppSpacing.md));
    }
    return Column(children: rows);
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.mood, required this.onTap});

  final Mood mood;
  final ValueChanged<Mood> onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = AppCopy.moodSubtitle(mood.id, mood.description);
    return Semantics(
      button: true,
      label: '${mood.label} mood. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: AppColors.moodTint(mood.id),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => onTap(mood),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 128),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Emoji(mood.emoji, size: 40),
                  const SizedBox(height: AppSpacing.sm),
                  Text(mood.label, style: textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle, style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
