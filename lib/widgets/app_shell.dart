import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/cart/cart_controller.dart';

/// Bottom navigation for the five main tabs: Mood, Restaurants, Ask, Orders, Cart.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartProvider.select((cart) => cart.itemCount));
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.mood_outlined), selectedIcon: Icon(Icons.mood), label: 'Mood'),
          const NavigationDestination(
              icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Restaurants'),
          const NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Ask'),
          const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Orders'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_bag),
            ),
            label: 'Cart',
          ),
        ],
      ),
    );
  }
}
