import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moodbite/core/router.dart';
import 'package:moodbite/core/theme.dart';
import 'package:moodbite/core/zone_check.dart';
import 'package:moodbite/features/browse/catalogue_repository.dart';
import 'package:moodbite/features/cart/cart_controller.dart';
import 'package:moodbite/features/location/location_service.dart';
import 'package:moodbite/features/orders/address_repository.dart';
import 'package:moodbite/features/orders/checkout_screen.dart';
import 'package:moodbite/features/orders/new_address_form.dart';
import 'package:moodbite/features/orders/order_repository.dart';
import 'package:moodbite/models/address.dart';
import 'package:moodbite/models/dish.dart';
import 'package:moodbite/models/geo_point.dart';
import 'package:moodbite/models/zone.dart';
import 'package:moodbite/widgets/sticky_total_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _bandra = Zone(id: 'z13', name: 'Bandra West', centre: GeoPoint(19.0596, 72.8295));
const _colaba = Zone(id: 'z01', name: 'Colaba', centre: GeoPoint(18.9067, 72.8147));

class FakeLocationService implements LocationService {
  FakeLocationService(this.outcome);

  final LocationOutcome outcome;

  @override
  Future<LocationOutcome> currentLocation() async => outcome;
}

class FakeAddressRepository implements AddressRepository {
  FakeAddressRepository(this.saved);

  final List<Address> saved;

  @override
  Future<List<Address>> fetchMine() async => List.of(saved);

  @override
  Future<Address> add({required String label, required String line1, required GeoPoint location}) async {
    final address = Address(id: 'a${saved.length + 1}', label: label, line1: line1, location: location);
    saved.insert(0, address);
    return address;
  }
}

class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository({this.failWith});

  final Object? failWith;
  String? addressId;
  String? restaurantId;
  List<CartLine>? lines;
  String? moodId;

  @override
  Future<String> placeOrder({
    required String addressId,
    required String restaurantId,
    required List<CartLine> lines,
    String? moodId,
  }) async {
    this.moodId = moodId;
    this.addressId = addressId;
    this.restaurantId = restaurantId;
    this.lines = lines;
    if (failWith != null) throw failWith!;
    return 'order-1';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class SeededCart extends CartController {
  SeededCart({this.moodId});

  final String? moodId;

  @override
  CartState build() => CartState.empty.startWith(
        const Dish(
          id: 'd001',
          restaurantId: 'r001',
          name: 'Fish and Chips',
          description: '',
          priceInr: 200,
          isVeg: false,
          category: 'main',
        ),
        'Leopold Cafe',
        moodId: moodId,
      );
}

Widget app({
  required Widget home,
  LocationService? location,
  AddressRepository? addresses,
  OrderRepository? orders,
  GoRouter? router,
  String? cartMood,
}) =>
    ProviderScope(
      overrides: [
        zonesProvider.overrideWith((ref) async => [_bandra, _colaba]),
        if (location != null) locationServiceProvider.overrideWithValue(location),
        if (addresses != null) addressRepositoryProvider.overrideWithValue(addresses),
        if (orders != null) orderRepositoryProvider.overrideWithValue(orders),
        cartProvider.overrideWith(() => SeededCart(moodId: cartMood)),
      ],
      child: router != null
          ? MaterialApp.router(theme: AppTheme.light, routerConfig: router)
          : MaterialApp(theme: AppTheme.light, home: Scaffold(body: SingleChildScrollView(child: home))),
    );

void main() {
  const sanFrancisco = GeoPoint(37.7749, -122.4194);
  const nearBandra = GeoPoint(19.0610, 72.8300);

  group('NewAddressForm', () {
    testWidgets('empty form shows the address and location messages and submits nothing', (tester) async {
      AddressDraft? submitted;
      await tester.pumpWidget(app(home: NewAddressForm(onSubmit: (d) => submitted = d)));
      await tester.tap(find.text('Save address'));
      await tester.pump();
      expect(find.text('Enter your delivery address'), findsOneWidget);
      expect(find.text('Choose your delivery location'), findsOneWidget);
      expect(submitted, isNull);
    });

    testWidgets('a GPS fix outside Mumbai shows the full notice inside the area picker', (tester) async {
      await tester.pumpWidget(app(
        home: NewAddressForm(onSubmit: (_) {}),
        location: FakeLocationService(const LocationOutcome.found(sanFrancisco)),
      ));
      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();
      expect(find.text('Choose your area'), findsOneWidget);
      expect(find.text(ZoneCheck.outsideMumbaiNotice), findsOneWidget);
      expect(find.bySemanticsLabel('Notice: ${ZoneCheck.outsideMumbaiNotice}'), findsOneWidget);
      // The notice stays until an area is picked.
      await tester.pump(const Duration(seconds: 5));
      expect(find.text(ZoneCheck.outsideMumbaiNotice), findsOneWidget);
      await tester.tap(find.text('Bandra West'));
      await tester.pumpAndSettle();
      expect(find.text(ZoneCheck.outsideMumbaiNotice), findsNothing);
      expect(find.textContaining('Delivering to Bandra West'), findsOneWidget);
    });

    for (final failure in LocationFailure.values) {
      testWidgets('location failure $failure shows its own message inside the area picker', (tester) async {
        final message = LocationOutcome.failed(failure).message;
        await tester.pumpWidget(app(
          home: NewAddressForm(onSubmit: (_) {}),
          location: FakeLocationService(LocationOutcome.failed(failure)),
        ));
        await tester.tap(find.text('Use my location'));
        await tester.pumpAndSettle();
        expect(find.text('Choose your area'), findsOneWidget);
        expect(find.descendant(of: find.byType(BottomSheet), matching: find.text(message)), findsOneWidget);
        expect(find.bySemanticsLabel('Notice: $message'), findsOneWidget);
      });
    }

    testWidgets('area picker choice plus a valid address submits the draft', (tester) async {
      AddressDraft? submitted;
      await tester.pumpWidget(app(home: NewAddressForm(onSubmit: (d) => submitted = d)));
      await tester.tap(find.text('Choose area'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bandra West'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '  12 Hill Road  ');
      await tester.tap(find.text('Save address'));
      await tester.pump();
      expect(submitted?.line1, '12 Hill Road');
      expect(submitted?.label, 'Home');
      expect(submitted?.location, _bandra.centre);
    });

    testWidgets('a GPS fix inside Mumbai is accepted', (tester) async {
      AddressDraft? submitted;
      await tester.pumpWidget(app(
        home: NewAddressForm(onSubmit: (d) => submitted = d),
        location: FakeLocationService(const LocationOutcome.found(nearBandra)),
      ));
      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();
      expect(find.textContaining('near Bandra West'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Flat 4, Sea View');
      await tester.tap(find.text('Save address'));
      await tester.pump();
      expect(submitted?.location, nearBandra);
    });

    testWidgets('a too-short address is rejected', (tester) async {
      AddressDraft? submitted;
      await tester.pumpWidget(app(home: NewAddressForm(onSubmit: (d) => submitted = d)));
      await tester.tap(find.text('Choose area'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Colaba'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'abc');
      await tester.tap(find.text('Save address'));
      await tester.pump();
      expect(find.text('Enter your delivery address'), findsOneWidget);
      expect(submitted, isNull);
    });
  });

  group('CheckoutScreen', () {
    GoRouter routerFor() => GoRouter(
          initialLocation: AppRoutes.checkout,
          routes: [
            GoRoute(path: AppRoutes.checkout, builder: (context, state) => const CheckoutScreen()),
            GoRoute(
              path: '/order/:id/confirmed',
              builder: (context, state) => Text('confirmed ${state.pathParameters['id']}'),
            ),
          ],
        );

    final saved = Address(id: 'a1', label: 'Home', line1: '12 Hill Road', location: _bandra.centre);

    testWidgets('places the order with the cart contents and opens the confirmation', (tester) async {
      final orders = FakeOrderRepository();
      await tester.pumpWidget(app(
        home: const SizedBox(),
        router: routerFor(),
        addresses: FakeAddressRepository([saved]),
        orders: orders,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();
      expect(orders.addressId, 'a1');
      expect(orders.restaurantId, 'r001');
      expect(orders.lines?.single.dish.id, 'd001');
      expect(orders.lines?.single.quantity, 1);
      expect(orders.moodId, isNull, reason: 'a dish found by browsing sends no mood');
      expect(find.text('confirmed order-1'), findsOneWidget);
    });

    testWidgets('a cart built from a mood recommendation sends that mood to place_order', (tester) async {
      final orders = FakeOrderRepository();
      await tester.pumpWidget(app(
        home: const SizedBox(),
        router: routerFor(),
        addresses: FakeAddressRepository([saved]),
        orders: orders,
        cartMood: 'happy',
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();
      expect(orders.moodId, 'happy');
    });

    testWidgets('one flow: summary, address and a sticky total bar with the order button', (tester) async {
      await tester.pumpWidget(app(
        home: const SizedBox(),
        router: routerFor(),
        addresses: FakeAddressRepository([saved]),
        orders: FakeOrderRepository(),
      ));
      await tester.pumpAndSettle();
      expect(find.text('1. Order summary'), findsOneWidget);
      expect(find.text('1 x Fish and Chips'), findsOneWidget);
      expect(find.text('2. Delivery address'), findsOneWidget);
      expect(find.text('12 Hill Road'), findsOneWidget);
      expect(find.byType(StickyTotalBar), findsOneWidget);
      expect(find.text('Total · 1 item'), findsOneWidget);
      expect(find.text('Demo delivery: no real rider or payment is involved.'), findsOneWidget);
      expect(tester.getSize(find.widgetWithText(FilledButton, 'Place order')).height, greaterThanOrEqualTo(48));
    });

    testWidgets('the total bar is not scrolled away with the page', (tester) async {
      await tester.pumpWidget(app(
        home: const SizedBox(),
        router: routerFor(),
        addresses: FakeAddressRepository([saved]),
        orders: FakeOrderRepository(),
      ));
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(find.byType(StickyTotalBar));
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(StickyTotalBar)), before);
    });

    testWidgets('a server refusal is shown as a friendly message and the cart is kept', (tester) async {
      final orders = FakeOrderRepository(failWith: const PostgrestException(message: 'We deliver only in Mumbai'));
      await tester.pumpWidget(app(
        home: const SizedBox(),
        router: routerFor(),
        addresses: FakeAddressRepository([saved]),
        orders: orders,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Place order'));
      await tester.pumpAndSettle();
      expect(find.text('We deliver only in Mumbai'), findsOneWidget);
      expect(find.text('Place order'), findsOneWidget);
    });

    testWidgets('with no saved address the form is shown and the order button is not', (tester) async {
      await tester.pumpWidget(app(
        home: const SizedBox(),
        router: routerFor(),
        addresses: FakeAddressRepository([]),
        orders: FakeOrderRepository(),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Add your first delivery address.'), findsOneWidget);
      expect(find.text('Save address'), findsOneWidget);
      expect(find.textContaining('Place order'), findsNothing);
    });
  });
}
