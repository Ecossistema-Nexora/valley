import 'dart:convert';

import 'package:flutter/services.dart';
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
    final Set<String> activeModuleIds = await _loadActiveModuleIds();
    for (final String baseUrl in await _candidateBaseUrls()) {
      try {
        final http.Response response = await http
            .get(Uri.parse('$baseUrl/api/product-shell'))
            .timeout(const Duration(seconds: 12));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }
        final Map<String, dynamic> json =
            (jsonDecode(utf8.decode(response.bodyBytes))
                    as Map<dynamic, dynamic>)
                .cast<String, dynamic>();
        return _parseShell(baseUrl, json, activeModuleIds);
      } catch (error) {
        lastError = error;
      }
    }
    try {
      return await _loadBundledShell(activeModuleIds);
    } catch (error) {
      throw StateError(
        'Servidor Valley indisponivel: $lastError; fallback: $error',
      );
    }
  }

  Future<ProductActionResult> invokePath({
    required String baseUrl,
    required String path,
  }) async {
    final Uri uri = Uri.parse('$baseUrl$path');
    final http.Response response = await http
        .post(
          uri,
          headers: <String, String>{'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 20));

    final Map<String, dynamic> json =
        (jsonDecode(utf8.decode(response.bodyBytes)) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    final String status = json['status'] as String? ?? 'unknown';
    final Map<String, dynamic> payload =
        (json['payload'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
            .cast<String, dynamic>();

    return ProductActionResult(
      ok:
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          status == 'ok',
      status: status,
      action: json['action'] as String? ?? '',
      message: payload['message'] as String? ?? status,
      url: payload['url'] as String? ?? '',
    );
  }

  ProductShellData _parseShell(
    String baseUrl,
    Map<String, dynamic> json,
    Set<String> activeModuleIds,
  ) {
    final Map<String, dynamic> publicRuntime =
        (json['public_runtime'] as Map<dynamic, dynamic>? ??
                <dynamic, dynamic>{})
            .cast<String, dynamic>();
    final List<ProductModule> modules =
        (json['modules'] as List<dynamic>? ?? <dynamic>[])
            .map(
              (dynamic item) => ProductModule.fromJson(
                (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
              ),
            )
            .where(
              (ProductModule module) => activeModuleIds.contains(module.id),
            )
            .toList();
    final List<ProductItem> items =
        (json['items'] as List<dynamic>? ?? <dynamic>[])
            .map(
              (dynamic item) => ProductItem.fromJson(
                (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
              ),
            )
            .where(
              (ProductItem item) => activeModuleIds.contains(item.moduleId),
            )
            .toList();
    final Map<String, dynamic> filteredRawData = Map<String, dynamic>.from(
      json,
    );
    filteredRawData['modules'] = modules
        .map(
          (ProductModule module) => <String, String>{
            'id': module.id,
            'label': module.label,
            'subtitle': module.subtitle,
            'badge': module.badge,
          },
        )
        .toList();
    filteredRawData['items'] = items
        .map((ProductItem item) => item.raw)
        .toList();
    filteredRawData['module_screens'] =
        (json['module_screens'] as List<dynamic>? ?? <dynamic>[]).where((
          dynamic item,
        ) {
          final Map<String, dynamic> value = (item as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
          return activeModuleIds.contains(value['module_id'] as String? ?? '');
        }).toList();

    return ProductShellData(
      baseUrl: baseUrl,
      title: json['title'] as String? ?? 'Valley',
      subtitle: json['subtitle'] as String? ?? '',
      generatedAtUtc: json['generated_at_utc'] as String? ?? '',
      modules: modules,
      summary: ProductSummary.fromJson(
        (json['summary'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{})
            .cast<String, dynamic>(),
      ),
      items: items,
      publicUrl: publicRuntime['public_url'] as String? ?? '',
      rawData: filteredRawData,
    );
  }

  Future<Set<String>> _loadActiveModuleIds() async {
    final String manifestText = await rootBundle.loadString(
      'assets/data/valley_mvp_manifest.v1.json',
    );
    final Map<String, dynamic> manifest =
        (jsonDecode(manifestText) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    final Set<String> excluded =
        (manifest['excluded_modules'] as List<dynamic>? ?? <dynamic>[])
            .cast<String>()
            .toSet();
    return (manifest['included_modules'] as List<dynamic>? ?? <dynamic>[])
        .cast<String>()
        .where((String code) => !excluded.contains(code))
        .toSet();
  }

  Future<ProductShellData> _loadBundledShell(
    Set<String> activeModuleIds,
  ) async {
    final String catalogText = await rootBundle.loadString(
      'assets/data/valley_product_catalog.json',
    );
    final Map<String, dynamic> catalog =
        (jsonDecode(catalogText) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    return _parseShell(
      'asset://valley-product-catalog',
      catalog,
      activeModuleIds,
    );
  }

  Future<List<String>> _candidateBaseUrls() async {
    final Set<String> candidates = <String>{};

    void addCandidate(String? value) {
      final String normalized = _normalizeBaseUrl(value ?? '');
      if (normalized.startsWith('http')) {
        candidates.add(normalized);
      }
    }

    final String currentOrigin = Uri.base.origin;
    if (currentOrigin.startsWith('http')) {
      addCandidate(currentOrigin);
    }
    if (_envBaseUrl.trim().isNotEmpty) {
      addCandidate(_envBaseUrl);
    }

    try {
      final String adminDataText = await rootBundle.loadString(
        'assets/data/valley_admin_data.json',
      );
      final Map<String, dynamic> adminData =
          (jsonDecode(adminDataText) as Map<dynamic, dynamic>)
              .cast<String, dynamic>();
      final Map<String, dynamic> publicRuntime =
          (adminData['public_runtime'] as Map<dynamic, dynamic>? ??
                  <dynamic, dynamic>{})
              .cast<String, dynamic>();
      addCandidate(publicRuntime['public_url'] as String?);
    } catch (_) {
      // Mantem fallback fixo abaixo.
    }

    for (final String candidate in <String>[
      'http://10.0.2.2:8085',
      'http://127.0.0.1:8085',
      'http://localhost:8085',
      'http://192.168.1.2:8085',
      'https://aged-surgeons-opinion-wanna.trycloudflare.com',
      'http://10.0.2.2:8080',
      'http://127.0.0.1:8080',
      'http://localhost:8080',
    ]) {
      addCandidate(candidate);
    }

    return candidates.toList(growable: false);
  }

  String _normalizeBaseUrl(String value) =>
      value.trim().replaceAll(RegExp(r'/$'), '');
}
