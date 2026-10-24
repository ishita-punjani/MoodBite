import 'geo_point.dart';
import 'json.dart';

class OrderItem {
  const OrderItem({required this.name, required this.quantity, required this.priceInr});

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final dish = json['dishes'] as Map<String, dynamic>?;
    return OrderItem(
      name: dish?['name'] as String? ?? 'Dish',
      quantity: readInt(json['qty']),
      priceInr: readInt(json['price_at_order']),
    );
  }

  final String name;
  final int quantity;

  /// Price per unit when the order was placed.
  final int priceInr;

  int get totalInr => priceInr * quantity;
}

class Order {
  const Order({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantLocation,
    required this.deliveryLocation,
    required this.totalInr,
    required this.placedAt,
    required this.items,
  });

  /// Query for `orders`, joined to the restaurant and the ordered dishes.
  static const columns = 'id, restaurant_id, total, placed_at, delivery_lat, delivery_lng, '
      'restaurants(name, lat, lng), order_items(qty, price_at_order, dishes(name))';

  factory Order.fromJson(Map<String, dynamic> json) {
    final restaurant = json['restaurants'] as Map<String, dynamic>;
    final items = (json['order_items'] as List? ?? const []).cast<Map<String, dynamic>>();
    return Order(
      id: json['id'] as String,
      restaurantId: json['restaurant_id'] as String,
      restaurantName: restaurant['name'] as String,
      restaurantLocation: GeoPoint(readDouble(restaurant['lat']), readDouble(restaurant['lng'])),
      deliveryLocation: GeoPoint(readDouble(json['delivery_lat']), readDouble(json['delivery_lng'])),
      totalInr: readInt(json['total']),
      placedAt: DateTime.parse(json['placed_at'] as String).toLocal(),
      items: items.map(OrderItem.fromJson).toList(),
    );
  }

  final String id;
  final String restaurantId;
  final String restaurantName;
  final GeoPoint restaurantLocation;
  final GeoPoint deliveryLocation;
  final int totalInr;
  final DateTime placedAt;
  final List<OrderItem> items;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Duration elapsedAt(DateTime now) => now.difference(placedAt);
}
