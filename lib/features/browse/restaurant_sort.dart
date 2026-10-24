import '../../models/geo_point.dart';
import '../../models/restaurant.dart';

/// A restaurant with its straight-line distance from the delivery area
/// (`null` when no area has been chosen yet).
class RestaurantEntry {
  const RestaurantEntry(this.restaurant, this.distanceKm);

  final Restaurant restaurant;
  final double? distanceKm;

  /// "2.3 km", or `null` when the distance is unknown.
  String? get distanceLabel {
    final km = distanceKm;
    if (km == null) return null;
    return '${km.toStringAsFixed(1)} km';
  }
}

/// Nearest first when [from] is known (ties by name); otherwise A to Z.
List<RestaurantEntry> sortRestaurants(List<Restaurant> restaurants, GeoPoint? from) {
  final entries = [
    for (final r in restaurants) RestaurantEntry(r, from?.distanceKmTo(r.location)),
  ];
  entries.sort((a, b) {
    final byDistance = (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0);
    return byDistance != 0 ? byDistance : a.restaurant.name.toLowerCase().compareTo(b.restaurant.name.toLowerCase());
  });
  return entries;
}
