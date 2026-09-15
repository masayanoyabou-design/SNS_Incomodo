import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Wraps geolocator so the rest of the app never touches it directly.
class LocationService {
  /// Returns the device's current position, asking for permission if needed.
  Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('端末の位置情報がオフになっています。設定からオンにしてください');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('位置情報の利用が許可されませんでした');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException('位置情報の利用が拒否されています。端末の設定から許可してください');
    }

    const timeLimit = Duration(seconds: 30);
    final settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            // Use Android's own GPS instead of Google's fused provider, which
            // demands the user opt into "Google Location Accuracy" and fails
            // outright ("location service disabled") if they decline.
            forceLocationManager: true,
            timeLimit: timeLimit,
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high, timeLimit: timeLimit);

    try {
      return await Geolocator.getCurrentPosition(locationSettings: settings);
    } on TimeoutException {
      throw const LocationException(
          '現在地を取得できませんでした。屋外など電波の届く場所で、もう一度お試しください');
    }
  }
}
