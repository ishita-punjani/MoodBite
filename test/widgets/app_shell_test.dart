import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moodbite/core/theme.dart';
import 'package:moodbite/features/cart/cart_controller.dart';
import 'package:moodbite/models/dish.dart';
import 'package:moodbite/widgets/app_shell.dart';

class _SeededCart extends CartController {
  @override
  CartState build() => CartState.empty.startWith(
        const Dish(id: 'd1', restaurantId: 'r1', name: 'Dish', description: '', priceInr: 100, isVeg: true, category: 'main'),
        'Resto',
      );
}

GoRouter shellRouter() => GoRouter(
      initialLocation: '/mood',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(shell: shell),
          branches: [
            for (final name in ['mood', 'restaurants', 'ask', 'orders', 'cart'])
              StatefulShellBranch(routes: [
                GoRoute(path: '/$name', builder: (context, state) => Center(child: Text('$name page'))),
              ]),
          ],
        ),
      ],
    );

void main() {
  testWidgets('the tabs are Mood, Restaurants, Ask, Orders and Cart (no Search tab)', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(theme: AppTheme.light, routerConfig: shellRouter())));
    await tester.pumpAndSettle();
    final labels = tester.widgetList<NavigationDestination>(find.byType(NavigationDestination)).map((d) => d.label);
    expect(labels, ['Mood', 'Restaurants', 'Ask', 'Orders', 'Cart']);
    expect(find.text('Search'), findsNothing);
  });

  testWidgets('tapping Orders switches to the orders page', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp.router(theme: AppTheme.light, routerConfig: shellRouter())));
    await tester.pumpAndSettle();
    expect(find.text('mood page'), findsOneWidget);
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    expect(find.text('orders page'), findsOneWidget);
  });

  testWidgets('the cart tab shows a badge with the item count', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [cartProvider.overrideWith(_SeededCart.new)],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: shellRouter()),
    ));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(Badge), matching: find.text('1')), findsWidgets);
  });
}
