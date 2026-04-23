import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:valley_super_app/src/data/product_api_models.dart';

class ProductApiRepository {
  const ProductApiRepository();

  static const String _envBaseUrl = String.fromEnvironment(
    'VALLEY_PRODUCT_API_BASE_URL',
    defaultValue: '',
  );

  Future<ProductShellData> load() async {
    Object? lastError;
    for (final String baseUrl in _candidateBaseUrls()) {
      try {
        final http.Response response = await http
            .get(Uri.parse('$baseUrl/api/product-shell'))
            .timeout(const Duration(seconds: 12));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }
        final Map<String, dynamic> json =
            (jsonDecode(utf8.decode(response.bodyBytes)) as Map<dynamic, dynamic>)
                .cast<String, dynamic>();
        return _parseShell(baseUrl, json);
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('Servidor Valley indisponivel: $lastError');
  }

  Future<ProductActionResult> invoke({
    required String baseUrl,
    required ProductAction action,
  }) async {
    final Uri uri = Uri.parse('$baseUrl${action.path}');
    late final http.Response response;
    if (action.method.toUpperCase() == 'POST') {
      response = await http
          .post(uri, headers: <String, String>{'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 20));
    } else {
      response = await http.get(uri).timeout(const Duration(seconds: 20));
    }

    final Map<String, dynamic> json =
        (jsonDecode(utf8.decode(response.bodyBytes)) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    final String status = json['status'] as String? ?? 'unknown';
    final Map<String, dynamic> payload =
        (json['payload'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
            .cast<String, dynamic>();

    return ProductActionResult(
      ok: response.statusCode >= 200 &&
          response.statusCode < 300 &&
          status == 'ok',
      status: status,
      action: json['action'] as String? ?? action.id,
      message: _extractMessage(action, json, payload),
    );
  }

  ProductShellData _parseShell(String baseUrl, Map<String, dynamic> json) {
    final Map<String, dynamic> runtime =
        (json['runtime'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
            .cast<String, dynamic>();
    final Map<String, dynamic> bridgeStatus =
        (json['bridge_status'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
            .cast<String, dynamic>();
    final Map<String, dynamic> workStatus =
        (json['work_status'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
            .cast<String, dynamic>();
    final Map<String, dynamic> publicRuntime =
        (json['public_runtime'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
            .cast<String, dynamic>();

    return ProductShellData(
      baseUrl: baseUrl,
      service: json['service'] as String? ?? 'valley-product',
      generatedAtUtc: json['generated_at_utc'] as String? ?? '',
      serverOk: runtime['status'] == 'ok',
      telegramReady: bridgeStatus['telegram_ready'] as bool? ?? false,
      whatsappReady: bridgeStatus['whatsapp_ready'] as bool? ?? false,
      publicUrl: publicRuntime['public_url'] as String? ?? '',
      activityName: workStatus['activity_name'] as String? ?? 'Valley',
      progressPercent: (workStatus['progress_percent'] as num?)?.toInt() ?? 0,
      actions: (json['actions'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (dynamic item) => ProductAction.fromJson(
              (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
            ),
          )
          .where((ProductAction action) => action.active)
          .toList(),
    );
  }

  Iterable<String> _candidateBaseUrls() sync* {
    if (_envBaseUrl.trim().isNotEmpty) {
      yield _normalizeBaseUrl(_envBaseUrl);
    }
    yield 'http://10.0.2.2:8080';
    yield 'http://127.0.0.1:8080';
    yield 'http://localhost:8080';
  }

  String _normalizeBaseUrl(String value) => value.trim().replaceAll(RegExp(r'/$'), '');

  String _extractMessage(
    ProductAction action,
    Map<String, dynamic> json,
    Map<String, dynamic> payload,
  ) {
    final Object? stdout = payload['stdout'];
    if (stdout is String && stdout.trim().isNotEmpty) {
      return stdout.trim();
    }

    final String? actionName = payload['action'] as String?;
    if (actionName != null && actionName.isNotEmpty) {
      return actionName;
    }

    final String? routeStatus = json['status'] as String?;
    if (routeStatus != null && routeStatus.isNotEmpty) {
      return '${action.label} $routeStatus';
    }

    return action.label;
  }
}
