import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'dish_image.dart';

/// Green square-dot for veg, red for non-veg (the usual Indian food mark).
class VegBadge extends StatelessWidget {
  const VegBadge({super.key, required this.isVeg});

  final bool isVeg;

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? AppColors.success : AppColors.error;
    return Semantics(
      label: isVeg ? 'Vegetarian' : 'Non-vegetarian',
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(border: Border.all(color: color, width: 1.5)),
        alignment: Alignment.center,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// One dish row, used on the menu, search and recommendation screens.
class DishTile extends StatelessWidget {
  const DishTile({
    super.key,
    required this.name,
    required this.description,
    required this.priceInr,
    required this.isVeg,
    required this.category,
    this.caption,
    this.trailing,
    this.onTap,
  });

  final String name;
  final String description;
  final int priceInr;
  final bool isVeg;
  final String category;

  /// Extra line, e.g. the restaurant name or the reason for a recommendation.
  final String? caption;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DishImage(name: name, category: category, width: 72, height: 72),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      VegBadge(isVeg: isVeg),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(name, style: textTheme.titleMedium)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text('₹$priceInr', style: textTheme.bodyMedium),
                  if (description.isNotEmpty)
                    Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: textTheme.bodySmall),
                  if (caption != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(caption!, style: textTheme.bodySmall?.copyWith(color: AppColors.primary)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
          ],
        ),
      ),
    );
  }
}
