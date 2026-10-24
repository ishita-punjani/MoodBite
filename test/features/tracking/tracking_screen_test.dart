import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/core/theme.dart';
import 'package:moodbite/features/tracking/route_service.dart';
import 'package:moodbite/features/tracking/tracking_screen.dart';
import 'package:moodbite/models/geo_point.dart';
import 'package:moodbite/models/order.dart';

class StraightLineRouteService implements RouteService {
  @override
  Future<RouteResult> route(GeoPoint from, GeoPoint to) async =>
      RouteResult([from, to], isStraightLine: true);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Order orderPlacedAgo(Duration ago) => Order(
      id: 'o1',
      restaurantId: 'r001',
      restaurantName: 'Leopold Cafe',
      restaurantLocation: const GeoPoint(18.9227, 72.8317),
      deliveryLocation: const GeoPoint(19.0596, 72.8295),
      totalInr: 400,
      placedAt: DateTime.now().subtract(ago),
      items: const [OrderItem(name: 'Fish and Chips', quantity: 2, priceInr: 200)],
    );

Future<void> pumpTracking(WidgetTester tester, Order order) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [routeServiceProvider.overrideWithValue(StraightLineRouteService())],
      child: MaterialApp(theme: AppTheme.light, home: Scaffold(body: TrackingBody(order: order))),
    ),
  );
  await tester.pump();
}

String headline(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('tracking-headline'))).data!;

void main() {
  testWidgets('a new order shows the Demo delivery label and starts at Order placed', (tester) async {
    await pumpTracking(tester, orderPlacedAgo(const Duration(seconds: 2)));
    expect(find.text('Demo delivery'), findsOneWidget);
    expect(headline(tester), 'Order placed');
    expect(find.textContaining('Arriving in'), findsOneWidget);
    expect(find.byIcon(Icons.delivery_dining), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an order past the on-the-way time resumes with the rider on the map', (tester) async {
    await pumpTracking(tester, orderPlacedAgo(const Duration(seconds: 100)));
    expect(headline(tester), 'On the way');
    expect(find.byIcon(Icons.delivery_dining), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an old order shows Delivered', (tester) async {
    await pumpTracking(tester, orderPlacedAgo(const Duration(minutes: 10)));
    expect(headline(tester), 'Delivered');
    expect(find.text('Showing a straight line because the road route is unavailable.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
