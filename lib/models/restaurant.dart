import 'geo_point.dart';
import 'json.dart';

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.area,
    required this.address,
    required this.location,
    required this.cuisines,
    required this.priceLevel,
    required this.isOpen,
    this.minDishPrice,
    this.maxDishPrice,
  });

  /// Columns to request, so large embedding columns are never downloaded.
  static const columns =
      'id, name, area, address, lat, lng, cuisine, price_level, is_open';

  /// [columns] plus the prices of the restaurant's dishes (a PostgREST embed
  /// on the dishes foreign key), used to show the dish price range.
  static const columnsWithPrices = '$columns, dishes(price_inr)';

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    final prices = [
      for (final dish in json['dishes'] as List? ?? const [])
        if ((dish as Map<String, dynamic>)['price_inr'] != null) readInt(dish['price_inr']),
    ]..sort();
    return Restaurant(
        id: json['id'] as String,
        name: json['name'] as String,
        area: json['area'] as String,
        address: json['address'] as String? ?? '',
        location: GeoPoint(readDouble(json['lat']), readDouble(json['lng'])),
        cuisines: readStringList(json['cuisine']),
        priceLevel: readIntOrNull(json['price_level']) ?? 0,
        isOpen: json['is_open'] as bool? ?? true,
        minDishPrice: prices.isEmpty ? null : prices.first,
        maxDishPrice: prices.isEmpty ? null : prices.last,
    );
  }

  final String id;
  final String name;
  final String area;
  final String address;
  final GeoPoint location;
  final List<String> cuisines;

  /// 1 (budget) to 4 (luxury); 0 when unknown.
  final int priceLevel;
  final bool isOpen;

  /// Cheapest and dearest dish in rupees; null when the dish prices were not
  /// loaded or the restaurant has no dishes.
  final int? minDishPrice;
  final int? maxDishPrice;

  bool get hasPriceLevel => priceLevel >= 1 && priceLevel <= 4;

  /// "₹₹", or empty when the price level is unknown.
  String get priceLabel => hasPriceLevel ? '₹' * priceLevel : '';

  String? get _dishRangeText {
    final low = minDishPrice;
    final high = maxDishPrice;
    if (low == null || high == null) return null;
    return low == high ? 'Dishes at ₹$low' : 'Dishes from ₹$low to ₹$high';
  }

  /// "₹₹ · Dishes from ₹120 to ₹380"; either part is left out when unknown,
  /// and the whole line is null when both are.
  String? get priceLine {
    final parts = [if (hasPriceLevel) priceLabel, ?_dishRangeText];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Spoken form of [priceLine], null when there is nothing to say.
  String? get priceSemanticLabel {
    final parts = [
      if (hasPriceLevel) 'Price level $priceLevel of 4',
      if (minDishPrice != null && maxDishPrice != null)
        minDishPrice == maxDishPrice
            ? 'dishes at $minDishPrice rupees'
            : 'dishes from $minDishPrice to $maxDishPrice rupees',
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }
}
