import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/router.dart';
import '../core/theme.dart';
import '../models/dish.dart';
import '../models/dish_recommendation.dart';
import '../models/recommendation_result.dart';
import 'add_to_cart_button.dart';
import 'dish_image.dart';
import 'dish_tile.dart';

/// Dish-first result card used by the mood results and by the chat.
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.rec,
    required this.source,
    required this.moodId,
    this.reason,
    this.imageHeight = 160,
    this.showBadge = true,
  });

  final DishRecommendation rec;
  final RecommendationSource source;

  /// Mood the dish was recommended for; carried into the cart. `null` if none was detected.
  final String? moodId;
  final String? reason;
  final double imageHeight;

  /// Chat shows the badge once per reply bubble instead of on every card.
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dish = Dish(
      id: rec.dishId,
      restaurantId: rec.restaurantId,
      name: rec.dishName,
      description: rec.description,
      priceInr: rec.priceInr,
      isVeg: rec.isVeg,
      category: rec.category,
    );
    return Card(
      child: InkWell(
        onTap: () => context.push(AppRoutes.restaurant(rec.restaurantId)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                DishImage(
                  name: rec.dishName,
                  category: rec.category,
                  width: double.infinity,
                  height: imageHeight,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
                ),
                if (showBadge)
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: SourceBadge(source: source),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      VegBadge(isVeg: rec.isVeg),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(rec.dishName, style: textTheme.titleMedium)),
                      const SizedBox(width: AppSpacing.sm),
                      Text('₹${rec.priceInr}', style: textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text('${rec.restaurantName} · ${rec.distanceLabel}', style: textTheme.bodyMedium),
                  if (reason != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(reason!, style: textTheme.bodyMedium?.copyWith(color: AppColors.primary)),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AddToCartButton(dish: dish, restaurantName: rec.restaurantName, moodId: moodId),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "AI pick" or "Quick pick", shown on top of the dish photo.
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source, this.label});

  final RecommendationSource source;

  /// Defaults to the source's pick label.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isAi = source == RecommendationSource.ai;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isAi ? AppColors.primary : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: isAi ? AppColors.primary : AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAi ? Icons.auto_awesome : Icons.bolt,
              size: 16,
              color: isAi ? AppColors.onPrimary : AppColors.textPrimary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label ?? source.badgeLabel,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: isAi ? AppColors.onPrimary : AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
