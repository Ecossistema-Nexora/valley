// PROPOSITO: Persistir a fila offline-first do PDV do ERP Lojista em Windows e Linux.
// CONTEXTO: O PDV precisa registrar vendas, estoque espelho e eventos de sync mesmo sem internet.
// REGRAS: Nao apagar eventos antes de confirmacao remota, usar idempotency_key por evento e manter trilha auditavel.

import 'dart:convert';
import 'dart:io';

class MerchantErpOfflineStore {
  MerchantErpOfflineStore({Directory? storageRoot})
    : _storageRoot = storageRoot ?? _defaultStorageRoot();

  final Directory _storageRoot;

  File get _queueFile => File(
    '${_storageRoot.path}${Platform.pathSeparator}merchant_erp_offline_queue.json',
  );

  static Directory _defaultStorageRoot() {
    final String base = Platform.isWindows
        ? (Platform.environment['APPDATA'] ?? Directory.systemTemp.path)
        : (Platform.environment['XDG_DATA_HOME'] ??
              '${Platform.environment['HOME'] ?? Directory.systemTemp.path}${Platform.pathSeparator}.local${Platform.pathSeparator}share');
    return Directory('$base${Platform.pathSeparator}Valley');
  }

  Future<MerchantErpOfflineSnapshot> load() async {
    if (!await _queueFile.exists()) {
      return const MerchantErpOfflineSnapshot(
        events: <MerchantErpOfflineEvent>[],
      );
    }
    final Object? decoded = jsonDecode(await _queueFile.readAsString());
    if (decoded is! Map<String, Object?>) {
      return const MerchantErpOfflineSnapshot(
        events: <MerchantErpOfflineEvent>[],
      );
    }
    final Object? rawEvents = decoded['events'];
    final List<MerchantErpOfflineEvent> events = rawEvents is List<Object?>
        ? rawEvents
              .whereType<Map<String, Object?>>()
              .map(MerchantErpOfflineEvent.fromJson)
              .toList(growable: false)
        : const <MerchantErpOfflineEvent>[];
    return MerchantErpOfflineSnapshot(events: events);
  }

  Future<MerchantErpOfflineEvent> queueSale({
    required String deviceId,
    required double amountBrl,
    String paymentMethod = 'pending_authorization',
    List<Map<String, Object?>> items = const <Map<String, Object?>>[],
  }) async {
    final MerchantErpOfflineSnapshot snapshot = await load();
    final String localSaleId =
        'sale-${DateTime.now().microsecondsSinceEpoch}-${pid.toRadixString(36)}';
    final MerchantErpOfflineEvent event = MerchantErpOfflineEvent(
      localSaleId: localSaleId,
      deviceId: deviceId,
      eventType: 'pdv_sale',
      amountBrl: amountBrl,
      paymentMethod: paymentMethod,
      idempotencyKey: '$deviceId:pdv_sale:$localSaleId',
      createdAtUtc: DateTime.now().toUtc(),
      syncStatus: 'pending',
      items: items,
    );
    await _write(
      snapshot.copyWith(
        events: <MerchantErpOfflineEvent>[
          event,
          ...snapshot.events,
        ].take(500).toList(growable: false),
      ),
    );
    return event;
  }

  Future<void> markSynced(Set<String> idempotencyKeys) async {
    if (idempotencyKeys.isEmpty) {
      return;
    }
    final MerchantErpOfflineSnapshot snapshot = await load();
    await _write(
      snapshot.copyWith(
        events: snapshot.events
            .map(
              (MerchantErpOfflineEvent event) =>
                  idempotencyKeys.contains(event.idempotencyKey)
                  ? event.copyWith(syncStatus: 'synced')
                  : event,
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> _write(MerchantErpOfflineSnapshot snapshot) async {
    await _storageRoot.create(recursive: true);
    await _queueFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
    );
  }
}

class MerchantErpOfflineSnapshot {
  const MerchantErpOfflineSnapshot({required this.events});

  final List<MerchantErpOfflineEvent> events;

  List<MerchantErpOfflineEvent> get pending => events
      .where((MerchantErpOfflineEvent event) => event.syncStatus != 'synced')
      .toList(growable: false);

  MerchantErpOfflineSnapshot copyWith({
    List<MerchantErpOfflineEvent>? events,
  }) => MerchantErpOfflineSnapshot(events: events ?? this.events);

  Map<String, Object?> toJson() => <String, Object?>{
    'service': 'valley-merchant-erp-offline-store',
    'release_version': 'v045',
    'updated_at_utc': DateTime.now().toUtc().toIso8601String(),
    'events': events
        .map((MerchantErpOfflineEvent event) => event.toJson())
        .toList(growable: false),
  };
}

class MerchantErpOfflineEvent {
  const MerchantErpOfflineEvent({
    required this.localSaleId,
    required this.deviceId,
    required this.eventType,
    required this.amountBrl,
    required this.paymentMethod,
    required this.idempotencyKey,
    required this.createdAtUtc,
    required this.syncStatus,
    required this.items,
  });

  final String localSaleId;
  final String deviceId;
  final String eventType;
  final double amountBrl;
  final String paymentMethod;
  final String idempotencyKey;
  final DateTime createdAtUtc;
  final String syncStatus;
  final List<Map<String, Object?>> items;

  factory MerchantErpOfflineEvent.fromJson(Map<String, Object?> json) {
    return MerchantErpOfflineEvent(
      localSaleId: '${json['local_sale_id'] ?? ''}',
      deviceId: '${json['device_id'] ?? ''}',
      eventType: '${json['event_type'] ?? 'pdv_sale'}',
      amountBrl: double.tryParse('${json['amount_brl'] ?? 0}') ?? 0,
      paymentMethod: '${json['payment_method'] ?? 'pending_authorization'}',
      idempotencyKey: '${json['idempotency_key'] ?? ''}',
      createdAtUtc:
          DateTime.tryParse('${json['created_at_utc'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      syncStatus: '${json['sync_status'] ?? 'pending'}',
      items: json['items'] is List<Object?>
          ? (json['items'] as List<Object?>)
                .whereType<Map<String, Object?>>()
                .toList(growable: false)
          : const <Map<String, Object?>>[],
    );
  }

  MerchantErpOfflineEvent copyWith({String? syncStatus}) {
    return MerchantErpOfflineEvent(
      localSaleId: localSaleId,
      deviceId: deviceId,
      eventType: eventType,
      amountBrl: amountBrl,
      paymentMethod: paymentMethod,
      idempotencyKey: idempotencyKey,
      createdAtUtc: createdAtUtc,
      syncStatus: syncStatus ?? this.syncStatus,
      items: items,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'local_sale_id': localSaleId,
    'device_id': deviceId,
    'event_type': eventType,
    'amount_brl': amountBrl,
    'payment_method': paymentMethod,
    'idempotency_key': idempotencyKey,
    'created_at_utc': createdAtUtc.toIso8601String(),
    'sync_status': syncStatus,
    'items': items,
  };
}
