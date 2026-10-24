import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moodbite/core/router.dart';
import 'package:moodbite/core/theme.dart';
import 'package:moodbite/features/auth/session_controller.dart';
import 'package:moodbite/features/cart/cart_controller.dart';
import 'package:moodbite/features/cart/cart_screen.dart';
import 'package:moodbite/models/dish.dart';
import 'package:moodbite/models/profile.dart';
import 'package:moodbite/widgets/sticky_total_bar.dart';

class _Session extends ChangeNotifier implements SessionController {
  @override
  Profile? get profile => const Profile(id: 'u1', fullName: 'Priya Sharma');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _paneer = Dish(
  id: 'd1',
  restaurantId: 'r1',
  name: 'Paneer Tikka',
  description: '',
  priceInr: 240,
  isVeg: true,
  category: 'starter',
);

class _SeededCart extends CartController {
  @override
  CartState build() => CartState.empty.startWith(_paneer, 'Leopold Cafe').add(_paneer, 'Leopold Cafe').$1;
}

Widget host({required bool seeded}) => ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWithValue(_Session()),
        if (seeded) cartProvider.overrideWith(_SeededCart.new),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (context, state) => const CartScreen()),
          GoRoute(path: AppRoutes.checkout, builder: (context, state) => const Scaffold(body: Text('checkout page'))),
          GoRoute(path: AppRoutes.home, builder: (context, state) => const Scaffold(body: Text('mood page'))),
        ]),
      ),
    );

void main() {
  testWidgets('a cart with items shows a sticky total bar and Checkout opens the checkout flow', (tester) async {
    await tester.pumpWidget(host(seeded: true));
    await tester.pumpAndSettle();
    expect(find.text('Paneer Tikka'), findsOneWidget);
    expect(find.byType(StickyTotalBar), findsOneWidget);
    expect(find.text('Total · 2 items'), findsOneWidget);
    expect(find.text('₹480'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
    await tester.tap(find.text('Checkout'));
    await tester.pumpAndSettle();
    expect(find.text('checkout page'), findsOneWidget);
  });

  testWidgets('the total bar stays on screen while a long cart scrolls', (tester) async {
    await tester.pumpWidget(host(seeded: true));
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.byType(StickyTotalBar));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(StickyTotalBar)), before);
  });

  testWidgets('an empty cart has a friendly message, no total bar, and a way to pick a mood', (tester) async {
    await tester.pumpWidget(host(seeded: false));
    await tester.pumpAndSettle();
    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.byType(StickyTotalBar), findsNothing);
    await tester.tap(find.text('Pick a mood'));
    await tester.pumpAndSettle();
    expect(find.text('mood page'), findsOneWidget);
  });

  testWidgets('the app bar shows the logo, the title and the profile avatar', (tester) async {
    await tester.pumpWidget(host(seeded: false));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('Cart')), findsOneWidget);
    expect(find.text('PS'), findsOneWidget);
  });

  group('StickyTotalBar', () {
    Widget bar({VoidCallback? onPressed, bool busy = false}) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            bottomNavigationBar: StickyTotalBar(totalInr: 350, buttonLabel: 'Go', onPressed: onPressed, busy: busy),
          ),
        );

    testWidgets('shows the total and runs the action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(bar(onPressed: () => taps++));
      expect(find.text('₹350'), findsOneWidget);
      await tester.tap(find.text('Go'));
      expect(taps, 1);
      expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
    });

    testWidgets('is disabled with no action, and while busy shows a spinner', (tester) async {
      await tester.pumpWidget(bar());
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      await tester.pumpWidget(bar(onPressed: () {}, busy: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    });
  });
}
