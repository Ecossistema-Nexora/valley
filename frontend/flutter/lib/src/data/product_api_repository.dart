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

  Future<ProductActionResult> invokePath({
    required String baseUrl,
    required String path,
  }) async {
    final Uri uri = Uri.parse('$baseUrl$path');
    final http.Response response = await http
        .post(uri, headers: <String, String>{'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 20));

    final Map<String, dynamic> json =
        (jsonDecode(utf8.decode(response.bodyBytes)) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    final String status = json['status'] as String? ?? 'unknown';
    final Map<String, dynamic> payload =
        (json['payload'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
            .cast<String, dynamic>();

    return ProductActionResult(
      ok: response.statusCode >= 200 && response.statusCode < 300 && status == 'ok',
      status: status,
      action: json['action'] as String? ?? '',
      message: payload['message'] as String? ?? status,
      url: payload['url'] as String? ?? '',
    );
  }

  ProductShellData _parseShell(String baseUrl, Map<String, dynamic> json) {
    final Map<String, dynamic> publicRuntime =
        (json['public_runtime'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
            .cast<String, dynamic>();

    return ProductShellData(
      baseUrl: baseUrl,
      title: json['title'] as String? ?? 'Valley',
      subtitle: json['subtitle'] as String? ?? '',
      generatedAtUtc: json['generated_at_utc'] as String? ?? '',
      modules: (json['modules'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (dynamic item) => ProductModule.fromJson(
              (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
            ),
          )
          .toList(),
      summary: ProductSummary.fromJson(
        (json['summary'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
            .cast<String, dynamic>(),
      ),
      items: (json['items'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (dynamic item) => ProductItem.fromJson(
              (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
            ),
          )
          .toList(),
      publicUrl: publicRuntime['public_url'] as String? ?? '',
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
}
