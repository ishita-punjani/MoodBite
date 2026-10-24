import 'geo_point.dart';
import 'json.dart';

/// A Mumbai delivery zone centre.
class Zone {
  const Zone({required this.id, required this.name, required this.centre});

  static const columns = 'id, name, lat, lng';

  factory Zone.fromJson(Map<String, dynamic> json) => Zone(
        id: json['id'] as String,
        name: json['name'] as String,
        centre: GeoPoint(readDouble(json['lat']), readDouble(json['lng'])),
      );

  final String id;
  final String name;
  final GeoPoint centre;
}

/// A copy of [zones] sorted A to Z by name, ignoring case.
List<Zone> sortZonesByName(Iterable<Zone> zones) =>
    zones.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
