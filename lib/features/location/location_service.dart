import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/geo_point.dart';

enum LocationFailure { servicesOff, denied, deniedForever, unavailable }

/// Either a device location or the reason there is none. Every failure has a
/// message that points the user to the area picker.
class LocationOutcome {
  const LocationOutcome.found(GeoPoint this.point) : failure = null;
  const LocationOutcome.failed(LocationFailure this.failure) : point = null;

  final GeoPoint? point;
  final LocationFailure? failure;

  String get message => switch (failure) {
        LocationFailure.servicesOff => 'Location is turned off. Turn it on, or choose your area.',
        LocationFailure.denied => 'Location permission was not granted. You can choose your area instead.',
        LocationFailure.deniedForever =>
          'Location permission is blocked. Allow it in the phone settings, or choose your area instead.',
        LocationFailure.unavailable => 'Could not get your location. Choose your area instead.',
        null => '',
      };
}

/// Device location behind an interface, so screens can be tested without GPS.
abstract class LocationService {
  Future<LocationOutcome> currentLocation();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  static const _fixTimeout = Duration(seconds: 15);

  @override
  Future<LocationOutcome> currentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationOutcome.failed(LocationFailure.servicesOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationOutcome.failed(LocationFailure.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const LocationOutcome.failed(LocationFailure.denied);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: _fixTimeout),
      );
      return LocationOutcome.found(GeoPoint(position.latitude, position.longitude));
    } on Exception {
      return const LocationOutcome.failed(LocationFailure.unavailable);
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) => const GeolocatorLocationService());
