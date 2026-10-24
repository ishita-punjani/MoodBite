import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moodbite/features/tracking/route_service.dart';
import 'package:moodbite/models/geo_point.dart';

void main() {
  const from = GeoPoint(18.9227, 72.8317);
  const to = GeoPoint(19.0596, 72.8295);

  RouteService serviceReturning(http.Response Function(http.Request) handler) =>
      RouteService(MockClient((request) async => handler(request)));

  test('decodes the OSRM geometry and asks for lng,lat order', () async {
    late Uri requested;
    final service = serviceReturning((request) {
      requested = request.url;
      return http.Response(
        jsonEncode({
          'code': 'Ok',
          'routes': [
            {'geometry': '_p~iF~ps|U_ulLnnqC_mqNvxq`@'},
          ],
        }),
        200,
      );
    });
    final result = await service.route(from, to);
    expect(result.isStraightLine, isFalse);
    expect(result.points, hasLength(3));
    expect(result.points.first.lat, closeTo(38.5, 1e-6));
    expect(requested.host, 'router.project-osrm.org');
    expect(requested.path, '/route/v1/driving/72.8317,18.9227;72.8295,19.0596');
    expect(requested.queryParameters['geometries'], 'polyline');
  });

  test('falls back to a straight line on a server error', () async {
    final result = await serviceReturning((_) => http.Response('busy', 429)).route(from, to);
    expect(result.isStraightLine, isTrue);
    expect(result.points, [from, to]);
  });

  test('falls back to a straight line when OSRM finds no route', () async {
    final body = jsonEncode({'code': 'NoRoute', 'routes': <Object>[]});
    final result = await serviceReturning((_) => http.Response(body, 200)).route(from, to);
    expect(result.isStraightLine, isTrue);
  });

  test('falls back to a straight line on malformed JSON', () async {
    final result = await serviceReturning((_) => http.Response('not json', 200)).route(from, to);
    expect(result.isStraightLine, isTrue);
  });

  test('falls back to a straight line when the network fails', () async {
    final service = RouteService(MockClient((_) async => throw http.ClientException('offline')));
    final result = await service.route(from, to);
    expect(result.isStraightLine, isTrue);
    expect(result.points, [from, to]);
  });
}
