import 'live_tracking_models.dart';

class ValleyLiveTrackingSocket {
  ValleyLiveTrackingSocket({
    required this.url,
    ValleyTelemetryNoiseFilter? noiseFilter,
  });

  final String url;

  Future<void> connect() async {}

  Future<bool> publishTelemetry(ValleyTelemetryPoint point) async => false;

  Future<void> close() async {}
}
