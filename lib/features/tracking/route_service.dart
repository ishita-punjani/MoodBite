import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../models/geo_point.dart';
import 'tracking_logic.dart';

/// A drawable route. [isStraightLine] is true when OSRM could not be used.
class RouteResult {
  const RouteResult(this.points, {required this.isStraightLine});

  final List<GeoPoint> points;
  final bool isStraightLine;
}

/// Road route from the public OSRM demo server (CLAUDE.md section 3).
/// Any failure (offline, slow, rate limited, bad JSON) falls back to a
/// straight line between the two points, so tracking never breaks.
class RouteService {
  RouteService(this._client);

  final http.Client _client;

  static const _timeout = Duration(seconds: 8);
  static const _host = 'router.project-osrm.org';

  Future<RouteResult> route(GeoPoint from, GeoPoint to) async {
    try {
      final uri = Uri.https(
        _host,
        '/route/v1/driving/${from.lng},${from.lat};${to.lng},${to.lat}',
        {'overview': 'full', 'geometries': 'polyline'},
      );
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return _straight(from, to);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['code'] != 'Ok') return _straight(from, to);
      final routes = json['routes'] as List;
      final geometry = (routes.first as Map<String, dynamic>)['geometry'] as String;
      final points = decodePolyline(geometry);
      if (points.length < 2) return _straight(from, to);
      return RouteResult(points, isStraightLine: false);
    } catch (_) {
      return _straight(from, to);
    }
  }

  RouteResult _straight(GeoPoint from, GeoPoint to) => RouteResult([from, to], isStraightLine: true);
}

final routeServiceProvider = Provider<RouteService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return RouteService(client);
});

/// Route from the restaurant (first) to the delivery point (second).
final orderRouteProvider = FutureProvider.autoDispose.family<RouteResult, (GeoPoint, GeoPoint)>(
  (ref, ends) => ref.watch(routeServiceProvider).route(ends.$1, ends.$2),
);
