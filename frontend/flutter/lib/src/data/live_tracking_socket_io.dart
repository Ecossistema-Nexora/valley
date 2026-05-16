import 'dart:convert';
import 'dart:io';

import 'live_tracking_models.dart';

class ValleyLiveTrackingSocket {
  ValleyLiveTrackingSocket({
    required this.url,
    ValleyTelemetryNoiseFilter? noiseFilter,
  }) : _noiseFilter = noiseFilter ?? ValleyTelemetryNoiseFilter();

  final String url;
  final ValleyTelemetryNoiseFilter _noiseFilter;
  WebSocket? _socket;

  Future<void> connect() async {
    _socket ??= await WebSocket.connect(url);
  }

  Future<bool> publishTelemetry(ValleyTelemetryPoint point) async {
    if (!_noiseFilter.shouldSend(point)) {
      return false;
    }
    await connect();
    _socket?.add(jsonEncode(point.toJson()));
    return true;
  }

  Future<void> close() async {
    final WebSocket? socket = _socket;
    _socket = null;
    await socket?.close(WebSocketStatus.normalClosure, 'tracking_finished');
  }
}
