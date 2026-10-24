import 'package:flutter_test/flutter_test.dart';
import 'package:moodbite/core/zone_check.dart';
import 'package:moodbite/models/geo_point.dart';
import 'package:moodbite/models/zone.dart';

void main() {
  const zones = [
    Zone(id: 'z01', name: 'Colaba', centre: GeoPoint(18.9067, 72.8147)),
    Zone(id: 'z13', name: 'Bandra West', centre: GeoPoint(19.0596, 72.8295)),
    Zone(id: 'z21', name: 'Powai', centre: GeoPoint(19.1176, 72.9060)),
  ];

  test('distance between Colaba and Bandra is about 17 km', () {
    final km = zones[0].centre.distanceKmTo(zones[1].centre);
    expect(km, closeTo(17.0, 0.5));
  });

  test('a point in Bandra matches the Bandra West zone', () {
    final match = ZoneCheck.nearest(const GeoPoint(19.0544, 72.8402), zones);
    expect(match?.zone.name, 'Bandra West');
    expect(match!.distanceKm, lessThan(2));
  });

  test('picks the closest of several zones in range', () {
    final match = ZoneCheck.nearest(
      const GeoPoint(19.0596, 72.8295),
      zones,
      radiusKm: 100,
    );
    expect(match?.zone.id, 'z13');
  });

  test('the emulator default (California) is outside Mumbai', () {
    const mountainView = GeoPoint(37.4220, -122.0841);
    expect(ZoneCheck.nearest(mountainView, zones), isNull);
    expect(ZoneCheck.validate(mountainView, zones), 'We deliver only in Mumbai');
  });

  test('a point just beyond 5 km from every zone is rejected', () {
    // About 5.6 km north of the Powai centre.
    expect(ZoneCheck.validate(const GeoPoint(19.1680, 72.9060), zones), 'We deliver only in Mumbai');
  });

  test('missing location asks the user to choose one', () {
    expect(ZoneCheck.validate(null, zones), 'Choose your delivery location');
    expect(ZoneCheck.validate(const GeoPoint(18.91, 72.82), zones), isNull);
  });
}
