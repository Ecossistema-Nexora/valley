class ProductAction {
  const ProductAction({
    required this.id,
    required this.label,
    required this.method,
    required this.path,
    required this.active,
  });

  factory ProductAction.fromJson(Map<String, dynamic> json) {
    return ProductAction(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      method: json['method'] as String? ?? 'GET',
      path: json['path'] as String? ?? '',
      active: json['active'] as bool? ?? false,
    );
  }

  final String id;
  final String label;
  final String method;
  final String path;
  final bool active;
}

class ProductShellData {
  const ProductShellData({
    required this.baseUrl,
    required this.service,
    required this.generatedAtUtc,
    required this.serverOk,
    required this.telegramReady,
    required this.whatsappReady,
    required this.publicUrl,
    required this.activityName,
    required this.progressPercent,
    required this.actions,
  });

  final String baseUrl;
  final String service;
  final String generatedAtUtc;
  final bool serverOk;
  final bool telegramReady;
  final bool whatsappReady;
  final String publicUrl;
  final String activityName;
  final int progressPercent;
  final List<ProductAction> actions;
}

class ProductActionResult {
  const ProductActionResult({
    required this.ok,
    required this.status,
    required this.action,
    required this.message,
  });

  final bool ok;
  final String status;
  final String action;
  final String message;
}
