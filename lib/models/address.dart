import 'geo_point.dart';
import 'json.dart';

class Address {
  const Address({
    required this.id,
    required this.label,
    required this.line1,
    required this.location,
    this.zoneId,
  });

  static const columns = 'id, label, line1, lat, lng, zone_id';

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: json['id'] as String,
        label: json['label'] as String? ?? 'Home',
        line1: json['line1'] as String,
        location: GeoPoint(readDouble(json['lat']), readDouble(json['lng'])),
        zoneId: json['zone_id'] as String?,
      );

  final String id;
  final String label;
  final String line1;
  final GeoPoint location;
  final String? zoneId;
}
