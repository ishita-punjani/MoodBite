import 'json.dart';

class Dish {
  const Dish({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.priceInr,
    required this.isVeg,
    required this.category,
  });

  /// Columns to request, so large embedding columns are never downloaded.
  static const columns =
      'id, restaurant_id, name, description, price_inr, is_veg, category';

  factory Dish.fromJson(Map<String, dynamic> json) => Dish(
        id: json['id'] as String,
        restaurantId: json['restaurant_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        priceInr: readInt(json['price_inr']),
        isVeg: json['is_veg'] as bool,
        category: json['category'] as String,
      );

  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final int priceInr;
  final bool isVeg;
  final String category;
}
