import '../models/geo_point.dart';
import '../models/zone.dart';

class ZoneMatch {
  const ZoneMatch(this.zone, this.distanceKm);

  final Zone zone;
  final double distanceKm;
}

/// Client-side Mumbai check (CLAUDE.md section 8). The server enforces the
/// same rule in `nearest_zone` / `place_order`; this gives instant feedback.
abstract final class ZoneCheck {
  /// Must match `app_config.zone_radius_km` in the database.
  static const radiusKm = 5.0;
  static const outsideMumbaiMessage = 'We deliver only in Mumbai';
  static const outsideMumbaiNotice =
      'We deliver only in Mumbai. Your location is outside our delivery area, so please choose your area below.';

  /// Closest zone within [radiusKm], or `null` if the point is outside Mumbai.
  static ZoneMatch? nearest(
    GeoPoint point,
    List<Zone> zones, {
    double radiusKm = radiusKm,
  }) {
    ZoneMatch? best;
    for (final zone in zones) {
      final km = point.distanceKmTo(zone.centre);
      if (km <= radiusKm && (best == null || km < best.distanceKm)) {
        best = ZoneMatch(zone, km);
      }
    }
    return best;
  }

  /// Validator-style: `null` when deliverable, otherwise a message.
  static String? validate(GeoPoint? point, List<Zone> zones) {
    if (point == null) return 'Choose your delivery location';
    return nearest(point, zones) == null ? outsideMumbaiMessage : null;
  }
}
