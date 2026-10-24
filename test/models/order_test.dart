import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/models/order.dart';

void main() {
  test('Order.fromJson reads the joined restaurant and items', () {
    final order = Order.fromJson({
      'id': 'o1',
      'restaurant_id': 'r001',
      'total': 540,
      'placed_at': '2026-10-20T10:00:00+00:00',
      'delivery_lat': 19.06,
      'delivery_lng': 72.83,
      'restaurants': {'name': 'Leopold Cafe', 'lat': 18.92, 'lng': 72.83},
      'order_items': [
        {'qty': 2, 'price_at_order': 200, 'dishes': {'name': 'Fish and Chips'}},
        {'qty': 1, 'price_at_order': 140, 'dishes': null},
      ],
    });
    expect(order.restaurantName, 'Leopold Cafe');
    expect(order.restaurantLocation.lat, 18.92);
    expect(order.deliveryLocation.lng, 72.83);
    expect(order.itemCount, 3);
    expect(order.items.first.totalInr, 400);
    expect(order.items.last.name, 'Dish');
    expect(order.placedAt.toUtc(), DateTime.utc(2026, 10, 20, 10));
    expect(order.elapsedAt(DateTime.utc(2026, 10, 20, 10, 1, 30)), const Duration(seconds: 90));
  });
}
