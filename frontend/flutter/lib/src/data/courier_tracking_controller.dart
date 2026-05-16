import 'live_tracking_models.dart';
import 'live_tracking_socket.dart';

class ValleyCourierTrackingController {
  ValleyCourierTrackingController({
    required this.session,
    required String websocketUrl,
    ValleyTelemetryNoiseFilter? noiseFilter,
  }) : _socket = ValleyLiveTrackingSocket(
         url: websocketUrl,
         noiseFilter: noiseFilter,
       );

  final ValleyTrackingSession session;
  final ValleyLiveTrackingSocket _socket;

  Future<void> start() => _socket.connect();

  Future<bool> publishPosition({
    required ValleyGeoPoint position,
    double? speedMetersPerSecond,
    double? headingDegrees,
    double? accuracyMeters,
    DateTime? recordedAt,
  }) {
    return _socket.publishTelemetry(
      ValleyTelemetryPoint(
        session: session,
        position: position,
        speedMetersPerSecond: speedMetersPerSecond,
        headingDegrees: headingDegrees,
        accuracyMeters: accuracyMeters,
        recordedAt: recordedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> stop() => _socket.close();
}
