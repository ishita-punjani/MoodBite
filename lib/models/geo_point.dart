import 'dart:math' as math;

/// A WGS84 coordinate. Kept independent of any map package so the pure
/// logic (zone check, tracking) is easy to unit test.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  static const _earthRadiusKm = 6371.0;

  /// Great-circle (straight-line) distance in kilometres.
  double distanceKmTo(GeoPoint other) {
    final p1 = _radians(lat);
    final p2 = _radians(other.lat);
    final dp = p2 - p1;
    final dl = _radians(other.lng - lng);
    final a = math.pow(math.sin(dp / 2), 2) +
        math.cos(p1) * math.cos(p2) * math.pow(math.sin(dl / 2), 2);
    return 2 * _earthRadiusKm * math.asin(math.sqrt(a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}
