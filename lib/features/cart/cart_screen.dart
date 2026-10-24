import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../widgets/brand.dart';
import '../../widgets/dish_tile.dart';
import '../../widgets/quantity_stepper.dart';
import '../../widgets/state_views.dart';
import '../../widgets/sticky_total_bar.dart';
import '../../widgets/user_avatar.dart';
import 'cart_controller.dart';

/// Cart tab: edit quantities, then continue to checkout.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final controller = ref.read(cartProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const BrandTitle('Cart'),
        actions: [
          if (!cart.isEmpty) TextButton(onPressed: controller.clear, child: const Text('Clear')),
          const ProfileAvatarButton(),
        ],
      ),
      body: cart.isEmpty
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const EmptyView(
                  emoji: '🛍️',
                  title: 'Your cart is empty',
                  message: 'Pick a mood or browse restaurants to add something tasty.',
                ),
                FilledButton.tonal(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Pick a mood'),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: [
                ListTile(
                  minVerticalPadding: AppSpacing.sm,
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(cart.restaurantName ?? 'Restaurant', style: textTheme.titleMedium),
                  subtitle: const Text('Tap to see the full menu'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: cart.restaurantId == null
                      ? null
                      : () => context.push(AppRoutes.restaurant(cart.restaurantId!)),
                ),
                const Divider(height: 1),
                for (final line in cart.lines)
                  DishTile(
                    name: line.dish.name,
                    description: '',
                    priceInr: line.dish.priceInr,
                    isVeg: line.dish.isVeg,
                    category: line.dish.category,
                    caption: 'Item total ₹${line.totalInr}',
                    trailing: QuantityStepper(
                      quantity: line.quantity,
                      onIncrement: () {
                        if (controller.add(line.dish, cart.restaurantName ?? '', moodId: line.moodId) ==
                            AddResult.maxQuantity) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text(Validators.quantityMessage)),
                          );
                        }
                      },
                      onDecrement: () => controller.decrement(line.dish.id),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : StickyTotalBar(
              totalInr: cart.totalInr,
              caption: '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'}',
              buttonLabel: 'Checkout',
              onPressed: () => context.push(AppRoutes.checkout),
            ),
    );
  }
}
