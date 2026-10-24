import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/features/tracking/tracking_logic.dart';
import 'package:moodbite/models/geo_point.dart';

void main() {
  const schedule = TrackingSchedule.demo;

  group('statusAt', () {
    test('follows placed -> preparing -> picked_up -> on_the_way -> delivered', () {
      expect(schedule.statusAt(Duration.zero), DeliveryStatus.placed);
      expect(schedule.statusAt(const Duration(seconds: 9)), DeliveryStatus.placed);
      expect(schedule.statusAt(const Duration(seconds: 10)), DeliveryStatus.preparing);
      expect(schedule.statusAt(const Duration(seconds: 50)), DeliveryStatus.pickedUp);
      expect(schedule.statusAt(const Duration(seconds: 65)), DeliveryStatus.onTheWay);
      expect(schedule.statusAt(const Duration(seconds: 165)), DeliveryStatus.delivered);
      expect(schedule.statusAt(const Duration(hours: 5)), DeliveryStatus.delivered);
    });

    test('negative elapsed time (clock skew) is treated as just placed', () {
      expect(schedule.statusAt(const Duration(seconds: -30)), DeliveryStatus.placed);
    });

    test('whole demo takes under three minutes', () {
      expect(schedule.deliveredAt, lessThan(const Duration(minutes: 3)));
    });

    test('database values match the orders.status check constraint', () {
      expect(DeliveryStatus.values.map((s) => s.dbValue),
          ['placed', 'preparing', 'picked_up', 'on_the_way', 'delivered']);
    });
  });

  group('routeProgress and ETA', () {
    test('progress is 0 before on the way, 0.5 halfway, 1 at delivery', () {
      expect(schedule.routeProgress(const Duration(seconds: 30)), 0);
      expect(schedule.routeProgress(const Duration(seconds: 115)), closeTo(0.5, 1e-9));
      expect(schedule.routeProgress(const Duration(seconds: 200)), 1);
    });

    test('ETA text counts down and ends at Delivered', () {
      expect(schedule.etaLabel(Duration.zero), 'Arriving in about 3 min');
      expect(schedule.etaLabel(const Duration(seconds: 120)), 'Arriving in under a minute');
      expect(schedule.etaLabel(const Duration(seconds: 165)), 'Delivered');
      expect(schedule.remaining(const Duration(seconds: -10)), schedule.deliveredAt);
    });
  });

  group('pointAlongRoute', () {
    const a = GeoPoint(19.0, 72.8);
    const b = GeoPoint(19.0, 72.9);
    const c = GeoPoint(19.1, 72.9);

    test('ends of the route', () {
      expect(pointAlongRoute([a, b, c], 0), a);
      expect(pointAlongRoute([a, b, c], 1), c);
      expect(pointAlongRoute([a], 0.5), a);
    });

    test('straight-line fallback interpolates between two points', () {
      final mid = pointAlongRoute([a, b], 0.5);
      expect(mid.lat, closeTo(19.0, 1e-9));
      expect(mid.lng, closeTo(72.85, 1e-9));
    });

    test('is weighted by distance, not by number of points', () {
      // a->b is about 10.5 km, b->c about 11.1 km; 25% lands inside the first leg.
      final p = pointAlongRoute([a, b, c], 0.25);
      expect(p.lat, closeTo(19.0, 1e-9));
      expect(p.lng, greaterThan(72.8));
      expect(p.lng, lessThan(72.9));
    });

    test('empty route throws', () {
      expect(() => pointAlongRoute(const [], 0.5), throwsArgumentError);
    });
  });

  group('decodePolyline', () {
    test('decodes the reference example', () {
      final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(points, hasLength(3));
      expect(points[0].lat, closeTo(38.5, 1e-9));
      expect(points[0].lng, closeTo(-120.2, 1e-9));
      expect(points[1].lat, closeTo(40.7, 1e-9));
      expect(points[1].lng, closeTo(-120.95, 1e-9));
      expect(points[2].lat, closeTo(43.252, 1e-9));
      expect(points[2].lng, closeTo(-126.453, 1e-9));
    });

    test('empty string gives no points; truncated input throws', () {
      expect(decodePolyline(''), isEmpty);
      expect(() => decodePolyline('_p~iF~ps|'), throwsFormatException);
    });
  });
}
