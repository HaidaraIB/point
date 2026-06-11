import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

enum LocationHelperError {
  mobileOnly,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class LocationResult {
  const LocationResult.success(this.position)
      : error = null;

  const LocationResult.failure(this.error)
      : position = null;

  final Position? position;
  final LocationHelperError? error;

  bool get isSuccess => position != null;
}

class LocationHelper {
  LocationHelper._();

  static double distanceMeters({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    return Geolocator.distanceBetween(fromLat, fromLng, toLat, toLng);
  }

  /// Works on mobile and web (browser location permission).
  static Future<LocationResult> getCurrentPosition() async {
    if (!kIsWeb) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult.failure(LocationHelperError.serviceDisabled);
      }
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return const LocationResult.failure(LocationHelperError.permissionDenied);
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult.failure(
        LocationHelperError.permissionDeniedForever,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationResult.success(position);
    } catch (_) {
      return const LocationResult.failure(LocationHelperError.unavailable);
    }
  }

  static Future<bool> openLocationSettings() => ph.openAppSettings();
}
