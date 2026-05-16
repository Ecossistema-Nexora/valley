import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ValleyLiveTrackingBridge {
  const ValleyLiveTrackingBridge._();

  static const MethodChannel _channel = MethodChannel('valley/live_tracking');

  static bool get _androidRuntime =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> startTracking({
    required String orderId,
    String orderLabel = 'pedido aceito',
    String status = 'accepted',
    String statusLabel = 'Pedido aceito',
    String courierName = 'Entregador Valley',
    String vehicleLabel = 'veiculo em rota',
    int etaMinutes = 14,
    int progress = 8,
    double courierLat = -23.5615,
    double courierLng = -46.6550,
    double pickupLat = -23.5650,
    double pickupLng = -46.6620,
    double destinationLat = -23.5535,
    double destinationLng = -46.6425,
    String trackingUrl = '',
    String authToken = '',
    String mapSnapshotUrl = '',
  }) async {
    if (!_androidRuntime) {
      return false;
    }
    return await _channel.invokeMethod<bool>('startTracking', <String, Object?>{
          'order_id': orderId,
          'order_label': orderLabel,
          'status': status,
          'status_label': statusLabel,
          'courier_name': courierName,
          'vehicle_label': vehicleLabel,
          'eta_minutes': etaMinutes,
          'progress': progress,
          'courier_lat': courierLat,
          'courier_lng': courierLng,
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'destination_lat': destinationLat,
          'destination_lng': destinationLng,
          if (trackingUrl.isNotEmpty) 'tracking_url': trackingUrl,
          if (authToken.isNotEmpty) 'auth_token': authToken,
          if (mapSnapshotUrl.isNotEmpty) 'map_snapshot_url': mapSnapshotUrl,
        }) ??
        false;
  }

  static Future<bool> updateTracking({
    required String orderId,
    String? status,
    String? statusLabel,
    String? courierName,
    String? vehicleLabel,
    int? etaMinutes,
    int? progress,
    double? courierLat,
    double? courierLng,
    double? pickupLat,
    double? pickupLng,
    double? destinationLat,
    double? destinationLng,
    String? trackingUrl,
    String? mapSnapshotUrl,
  }) async {
    if (!_androidRuntime) {
      return false;
    }
    return await _channel
            .invokeMethod<bool>('updateTracking', <String, Object?>{
              'order_id': orderId,
              if (status != null) 'status': status,
              if (statusLabel != null) 'status_label': statusLabel,
              if (courierName != null) 'courier_name': courierName,
              if (vehicleLabel != null) 'vehicle_label': vehicleLabel,
              if (etaMinutes != null) 'eta_minutes': etaMinutes,
              if (progress != null) 'progress': progress,
              if (courierLat != null) 'courier_lat': courierLat,
              if (courierLng != null) 'courier_lng': courierLng,
              if (pickupLat != null) 'pickup_lat': pickupLat,
              if (pickupLng != null) 'pickup_lng': pickupLng,
              if (destinationLat != null) 'destination_lat': destinationLat,
              if (destinationLng != null) 'destination_lng': destinationLng,
              if (trackingUrl != null && trackingUrl.isNotEmpty)
                'tracking_url': trackingUrl,
              if (mapSnapshotUrl != null && mapSnapshotUrl.isNotEmpty)
                'map_snapshot_url': mapSnapshotUrl,
            }) ??
        false;
  }

  static Future<bool> stopTracking() async {
    if (!_androidRuntime) {
      return false;
    }
    return await _channel.invokeMethod<bool>('stopTracking') ?? false;
  }
}
