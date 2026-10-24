import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../constants/categories.dart';
import '../../core/errors.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../models/dish.dart';
import '../../models/restaurant.dart';
import '../../widgets/add_to_cart_button.dart';
import '../../widgets/dish_image.dart';
import '../../widgets/dish_tile.dart';
import '../../widgets/price_line.dart';
import '../../widgets/state_views.dart';
import '../cart/cart_controller.dart';
import 'catalogue_repository.dart';

class RestaurantMenuScreen extends ConsumerWidget {
  const RestaurantMenuScreen({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurant = ref.watch(restaurantProvider(restaurantId));
    final cartCount = ref.watch(cartProvider.select((cart) => cart.itemCount));

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (restaurant) {
          AsyncData(:final value) => value?.name ?? 'Menu',
          _ => 'Menu',
        }),
        actions: [
          IconButton(
            tooltip: 'Cart',
            onPressed: () => context.go(AppRoutes.cart),
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
        ],
      ),
      body: restaurant.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(restaurantProvider(restaurantId)),
        ),
        data: (value) => value == null
            ? const EmptyView(emoji: '🔍', title: 'Restaurant not found')
            : _Menu(restaurant: value),
      ),
    );
  }
}

class _Menu extends ConsumerWidget {
  const _Menu({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(menuProvider(restaurant.id));
    final textTheme = Theme.of(context).textTheme;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RestaurantImage(
          restaurantId: restaurant.id,
          width: double.infinity,
          height: 180,
          borderRadius: BorderRadius.zero,
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(restaurant.name, style: textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(restaurant.cuisines.join(', '), style: textTheme.bodyMedium),
              PriceLine(restaurant),
              Text('${restaurant.area} · ${restaurant.address}', style: textTheme.bodySmall),
              if (!restaurant.isOpen) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Closed right now', style: textTheme.bodyMedium?.copyWith(color: AppColors.error)),
              ],
            ],
          ),
        ),
      ],
    );

    return menu.when(
      loading: () => Column(children: [header, const Expanded(child: LoadingView())]),
      error: (e, _) => Column(children: [
        header,
        Expanded(
          child: ErrorView(message: friendlyError(e), onRetry: () => ref.invalidate(menuProvider(restaurant.id))),
        ),
      ]),
      data: (dishes) {
        if (dishes.isEmpty) {
          return Column(children: [
            header,
            const Expanded(child: EmptyView(emoji: '🍽️', title: 'No dishes on the menu yet')),
          ]);
        }
        final sections = _groupByCategory(dishes);
        return ListView(
          children: [
            header,
            for (final entry in sections.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
                child: Text(DishCategories.labelFor(entry.key), style: textTheme.titleMedium),
              ),
              for (final dish in entry.value)
                DishTile(
                  name: dish.name,
                  description: dish.description,
                  priceInr: dish.priceInr,
                  isVeg: dish.isVeg,
                  category: dish.category,
                  trailing: restaurant.isOpen
                      ? AddToCartButton(dish: dish, restaurantName: restaurant.name)
                      : null,
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }

  static Map<String, List<Dish>> _groupByCategory(List<Dish> dishes) {
    final sections = <String, List<Dish>>{};
    for (final dish in dishes) {
      sections.putIfAbsent(dish.category, () => []).add(dish);
    }
    return sections;
  }
}
