import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/validators.dart';
import '../features/cart/cart_controller.dart';
import '../models/dish.dart';
import 'quantity_stepper.dart';

/// "Add" button that turns into a quantity stepper once the dish is in the cart.
class AddToCartButton extends ConsumerWidget {
  const AddToCartButton({super.key, required this.dish, required this.restaurantName, this.moodId});

  final Dish dish;
  final String restaurantName;

  /// Set when the dish comes from a mood's recommendations; `null` when browsing.
  final String? moodId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quantity = ref.watch(cartProvider.select((cart) => cart.quantityOf(dish.id)));
    final cart = ref.read(cartProvider.notifier);

    if (quantity == 0) {
      return OutlinedButton(
        onPressed: () => _add(context, ref),
        child: const Text('Add'),
      );
    }
    return QuantityStepper(
      quantity: quantity,
      onIncrement: () => _add(context, ref),
      onDecrement: () => cart.decrement(dish.id),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider.notifier);
    switch (cart.add(dish, restaurantName, moodId: moodId)) {
      case AddResult.added:
        return;
      case AddResult.maxQuantity:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(Validators.quantityMessage)),
        );
      case AddResult.differentRestaurant:
        final current = ref.read(cartProvider).restaurantName ?? 'another restaurant';
        final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Start a new cart?'),
            content: Text(
              'Your cart has dishes from $current. Each order comes from one '
              'restaurant, so adding this will clear your current cart.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep cart')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start new')),
            ],
          ),
        );
        if (replace == true) cart.startWith(dish, restaurantName, moodId: moodId);
    }
  }
}
