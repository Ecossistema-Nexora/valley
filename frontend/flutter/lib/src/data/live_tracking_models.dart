import 'dart:math' as math;

class ValleyGeoPoint {
  const ValleyGeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  Map<String, Object> toJson() => <String, Object>{
    'latitude': latitude,
    'longitude': longitude,
  };

  static double distanceMeters(ValleyGeoPoint a, ValleyGeoPoint b) {
    const double earthRadius = 6371000;
    final double dLat = _radians(b.latitude - a.latitude);
    final double dLng = _radians(b.longitude - a.longitude);
    final double lat1 = _radians(a.latitude);
    final double lat2 = _radians(b.latitude);
    final double h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}

class ValleyTrackingSession {
  const ValleyTrackingSession({
    required this.orderId,
    required this.trackingCode,
    required this.courierId,
    required this.merchantId,
    required this.pickup,
    required this.destination,
    this.status = 'accepted',
  });

  final String orderId;
  final String trackingCode;
  final String courierId;
  final String merchantId;
  final ValleyGeoPoint pickup;
  final ValleyGeoPoint destination;
  final String status;

  Map<String, Object> toJson() => <String, Object>{
    'order_id': orderId,
    'tracking_code': trackingCode,
    'courier_id': courierId,
    'merchant_id': merchantId,
    'pickup': pickup.toJson(),
    'destination': destination.toJson(),
    'status': status,
  };
}

class ValleyTelemetryPoint {
  const ValleyTelemetryPoint({
    required this.session,
    required this.position,
    required this.recordedAt,
    this.speedMetersPerSecond,
    this.headingDegrees,
    this.accuracyMeters,
  });

  final ValleyTrackingSession session;
  final ValleyGeoPoint position;
  final DateTime recordedAt;
  final double? speedMetersPerSecond;
  final double? headingDegrees;
  final double? accuracyMeters;

  Map<String, Object?> toJson() => <String, Object?>{
    'type': 'courier.telemetry',
    'order_id': session.orderId,
    'tracking_code': session.trackingCode,
    'courier_id': session.courierId,
    'merchant_id': session.merchantId,
    'latitude': position.latitude,
    'longitude': position.longitude,
    'speed_mps': speedMetersPerSecond,
    'heading_degrees': headingDegrees,
    'accuracy_meters': accuracyMeters,
    'recorded_at_utc': recordedAt.toUtc().toIso8601String(),
  };
}

class ValleyTelemetryNoiseFilter {
  ValleyTelemetryNoiseFilter({
    this.minDistanceMeters = 8,
    this.maxStationaryInterval = const Duration(seconds: 30),
  });

  final double minDistanceMeters;
  final Duration maxStationaryInterval;
  ValleyTelemetryPoint? _lastSent;

  bool shouldSend(ValleyTelemetryPoint point) {
    final ValleyTelemetryPoint? last = _lastSent;
    if (last == null) {
      _lastSent = point;
      return true;
    }
    final double distance = ValleyGeoPoint.distanceMeters(
      last.position,
      point.position,
    );
    final Duration elapsed = point.recordedAt.difference(last.recordedAt).abs();
    if (distance >= minDistanceMeters || elapsed >= maxStationaryInterval) {
      _lastSent = point;
      return true;
    }
    return false;
  }
}
