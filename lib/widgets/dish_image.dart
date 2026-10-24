import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/categories.dart';
import '../constants/dish_images.dart';
import '../core/theme.dart';
import '../features/browse/catalogue_repository.dart';
import 'emoji.dart';

const _defaultRadius = BorderRadius.all(Radius.circular(AppRadius.md));

/// Which dish photos are bundled with the app. Falls back to "none" (emoji
/// placeholders everywhere) if the asset list cannot be read.
final dishImageResolverProvider = FutureProvider<DishImageResolver>((ref) async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final dishAssets = manifest.listAssets().where((path) => path.startsWith('assets/dishes/'));
    return DishImageResolver(dishAssets.toSet());
  } catch (_) {
    return DishImageResolver.none;
  }
});

/// A dish photo, or the category emoji when no photo is available.
class DishImage extends ConsumerWidget {
  const DishImage({
    super.key,
    required this.name,
    required this.category,
    this.width,
    this.height,
    this.borderRadius = _defaultRadius,
  });

  final String name;
  final String category;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.watch(dishImageResolverProvider).asData?.value ?? DishImageResolver.none;
    final asset = resolver.assetFor(name, category);
    final placeholder = _Placeholder(category: category, width: width, height: height, borderRadius: borderRadius);
    if (asset == null) return placeholder;
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.asset(
        asset,
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheWidth: 800,
        semanticLabel: name,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

/// A restaurant's picture: the photo of its first dish.
class RestaurantImage extends ConsumerWidget {
  const RestaurantImage({
    super.key,
    required this.restaurantId,
    this.width,
    this.height,
    this.borderRadius = _defaultRadius,
  });

  final String restaurantId;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = ref.watch(coverDishesProvider).asData?.value[restaurantId];
    return DishImage(
      name: cover?.name ?? '',
      category: cover?.category ?? '',
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.category, this.width, this.height, required this.borderRadius});

  final String category;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final shortSide = [width, height].whereType<double>().where((v) => v.isFinite).fold<double>(96, math.min);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(AppColors.categoryTint(category), Colors.white, 0.45)!,
            AppColors.categoryTint(category),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Emoji(
        DishCategories.emojiFor(category),
        label: category.isEmpty ? 'Dish' : '${DishCategories.labelFor(category)} dish',
        size: (shortSide * 0.55).clamp(28, 64),
      ),
    );
  }
}
