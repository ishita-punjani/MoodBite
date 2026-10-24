import 'json.dart';

/// One row from the `recommend_dishes` RPC.
class DishRecommendation {
  const DishRecommendation({
    required this.dishId,
    required this.dishName,
    required this.description,
    required this.priceInr,
    required this.isVeg,
    required this.category,
    required this.restaurantId,
    required this.restaurantName,
    required this.area,
    required this.distanceKm,
    required this.score,
    this.reason,
  });

  factory DishRecommendation.fromJson(Map<String, dynamic> json) =>
      DishRecommendation(
        dishId: json['dish_id'] as String,
        dishName: json['dish_name'] as String,
        description: json['description'] as String? ?? '',
        priceInr: readInt(json['price_inr']),
        isVeg: json['is_veg'] as bool,
        category: json['category'] as String,
        restaurantId: json['restaurant_id'] as String,
        restaurantName: json['restaurant_name'] as String,
        area: json['area'] as String,
        distanceKm: readDouble(json['distance_km']),
        score: readDouble(json['score']),
        reason: json['reason'] as String?,
      );

  final String dishId;
  final String dishName;
  final String description;
  final int priceInr;
  final bool isVeg;
  final String category;
  final String restaurantId;
  final String restaurantName;
  final String area;
  final double distanceKm;
  final double score;

  /// One-line reason written by the AI (or the server's template); null for
  /// rows that came straight from the SQL scoring.
  final String? reason;

  /// Rounded for display, e.g. "1.2 km".
  String get distanceLabel => '${distanceKm.toStringAsFixed(1)} km';
}
