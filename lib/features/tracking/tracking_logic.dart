import 'dart:math' as math;

import '../../models/geo_point.dart';

/// Simulated ("Demo delivery") order status, derived only from the time
/// since the order was placed, so reopening the screen resumes correctly.
enum DeliveryStatus {
  placed('placed', 'Order placed'),
  preparing('preparing', 'Preparing your food'),
  pickedUp('picked_up', 'Picked up'),
  onTheWay('on_the_way', 'On the way'),
  delivered('delivered', 'Delivered');

  const DeliveryStatus(this.dbValue, this.label);

  /// Value used in the `orders.status` column.
  final String dbValue;
  final String label;
}

/// When each status starts, measured from `placed_at`.
/// Compressed to under three minutes for demos.
class TrackingSchedule {
  const TrackingSchedule({
    this.preparingAt = const Duration(seconds: 10),
    this.pickedUpAt = const Duration(seconds: 50),
    this.onTheWayAt = const Duration(seconds: 65),
    this.deliveredAt = const Duration(seconds: 165),
  });

  static const demo = TrackingSchedule();

  final Duration preparingAt;
  final Duration pickedUpAt;
  final Duration onTheWayAt;
  final Duration deliveredAt;

  /// Negative elapsed time (device clock behind the server) counts as zero.
  DeliveryStatus statusAt(Duration elapsed) {
    if (elapsed >= deliveredAt) return DeliveryStatus.delivered;
    if (elapsed >= onTheWayAt) return DeliveryStatus.onTheWay;
    if (elapsed >= pickedUpAt) return DeliveryStatus.pickedUp;
    if (elapsed >= preparingAt) return DeliveryStatus.preparing;
    return DeliveryStatus.placed;
  }

  /// How far along the route the rider is: 0 until "on the way", 1 once delivered.
  double routeProgress(Duration elapsed) {
    if (elapsed <= onTheWayAt) return 0;
    if (elapsed >= deliveredAt) return 1;
    final travelled = (elapsed - onTheWayAt).inMilliseconds;
    final total = (deliveredAt - onTheWayAt).inMilliseconds;
    return travelled / total;
  }

  Duration remaining(Duration elapsed) {
    final left = deliveredAt - elapsed;
    if (left.isNegative) return Duration.zero;
    return left > deliveredAt ? deliveredAt : left;
  }

  String etaLabel(Duration elapsed) {
    final left = remaining(elapsed);
    if (left == Duration.zero) return 'Delivered';
    if (left < const Duration(minutes: 1)) return 'Arriving in under a minute';
    final minutes = (left.inSeconds / 60).ceil();
    return 'Arriving in about $minutes min';
  }
}

/// Point at [fraction] (0-1) of the total length of [route], so the marker
/// moves at constant speed however unevenly the route points are spaced.
GeoPoint pointAlongRoute(List<GeoPoint> route, double fraction) {
  if (route.isEmpty) throw ArgumentError.value(route, 'route', 'is empty');
  if (route.length == 1 || fraction <= 0) return route.first;
  if (fraction >= 1) return route.last;

  final segments = <double>[
    for (var i = 1; i < route.length; i++) route[i - 1].distanceKmTo(route[i]),
  ];
  final total = segments.fold<double>(0, (sum, km) => sum + km);
  if (total == 0) return route.first;

  var target = total * fraction;
  for (var i = 0; i < segments.length; i++) {
    final length = segments[i];
    if (target <= length) {
      final t = length == 0 ? 0.0 : target / length;
      final a = route[i];
      final b = route[i + 1];
      return GeoPoint(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);
    }
    target -= length;
  }
  return route.last;
}

/// Decodes an encoded polyline (Google algorithm, as returned by OSRM with
/// `geometries=polyline`, precision 5).
List<GeoPoint> decodePolyline(String encoded, {int precision = 5}) {
  final factor = math.pow(10, precision);
  final points = <GeoPoint>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  int nextValue() {
    var result = 0;
    var shift = 0;
    int byte;
    do {
      if (index >= encoded.length) {
        throw const FormatException('Truncated polyline');
      }
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  while (index < encoded.length) {
    lat += nextValue();
    lng += nextValue();
    points.add(GeoPoint(lat / factor, lng / factor));
  }
  return points;
}
