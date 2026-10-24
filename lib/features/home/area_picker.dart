import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/theme.dart';
import '../../models/zone.dart';
import '../../widgets/state_views.dart';
import '../browse/catalogue_repository.dart';
import 'home_controllers.dart';

/// Bottom sheet listing the Mumbai delivery areas. Returns the chosen zone.
/// A [notice] (why the picker opened) stays visible at the top until the sheet closes.
Future<Zone?> showAreaPicker(BuildContext context, {String? notice}) => showModalBottomSheet<Zone>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AreaPickerSheet(notice: notice),
    );

class _AreaPickerSheet extends ConsumerWidget {
  const _AreaPickerSheet({this.notice});

  final String? notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = ref.watch(zonesProvider);
    final selected = ref.watch(deliveryZoneProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text('Choose your area', style: Theme.of(context).textTheme.titleMedium),
            ),
            if (notice == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
                child: Text('We deliver only in Mumbai.', style: Theme.of(context).textTheme.bodySmall),
              )
            else
              _AreaNotice(message: notice!),
            Expanded(
              child: zones.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  message: friendlyError(e),
                  onRetry: () => ref.invalidate(zonesProvider),
                ),
                data: (list) => ListView(
                  children: [
                    for (final zone in sortZonesByName(list))
                      ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(zone.name),
                        trailing: zone.id == selected?.id ? const Icon(Icons.check, color: AppColors.primary) : null,
                        onTap: () {
                          ref.read(deliveryZoneProvider.notifier).select(zone);
                          Navigator.pop(context, zone);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaNotice extends StatelessWidget {
  const _AreaNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Notice: $message',
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.primary),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium)),
            ],
          ),
        ),
      ),
    );
  }
}
