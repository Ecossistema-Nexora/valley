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
  static const String _releaseBaseUrl =
      'https://admin.brasildesconto.com.br/product';
  static const String _bundledStockRuntimeAsset =
      'assets/data/valley_stock_runtime_ptbr.json';

  Future<ProductShellData> load() async {
    Object? lastError;
    final Set<String> activeModuleIds = await _loadActiveModuleIds();
    if (_shouldPreferBundledShell()) {
      try {
        final ProductShellData bundledShell = await _loadBundledShell(
          activeModuleIds,
        );
        return await _withIntegratedStockCatalog(
          bundledShell,
          preferredBaseUrl: bundledShell.baseUrl,
        );
      } catch (error) {
        lastError = error;
      }
    }
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
        final ProductShellData shell = _parseShell(baseUrl, json, activeModuleIds);
        return await _withIntegratedStockCatalog(
          shell,
          preferredBaseUrl: baseUrl,
        );
      } catch (error) {
        lastError = error;
      }
    }
    try {
      final ProductShellData bundledShell = await _loadBundledShell(
        activeModuleIds,
      );
      return await _withIntegratedStockCatalog(
        bundledShell,
        preferredBaseUrl: bundledShell.baseUrl,
      );
    } catch (error) {
      throw StateError(
        'Servidor Valley indisponivel: $lastError; fallback: $error',
      );
    }
  }

  bool _shouldPreferBundledShell() {
    if (_envBaseUrl.trim().isNotEmpty) {
      return false;
    }
    final Uri base = Uri.base;
    if (base.scheme != 'http' && base.scheme != 'https') {
      return true;
    }
    final String host = base.host.toLowerCase();
    return host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
  }

  Future<List<ProductItem>> loadStockCatalog({String? preferredBaseUrl}) async {
    Object? lastError;
    final List<String> candidates = <String>[];
    final Set<String> seen = <String>{};

    void addCandidate(String? value) {
      final String normalized = _normalizeBaseUrl(value ?? '');
      if (!normalized.startsWith('http') || !seen.add(normalized)) {
        return;
      }
      candidates.add(normalized);
    }

    addCandidate(preferredBaseUrl);
    for (final String baseUrl in await _candidateBaseUrls()) {
      addCandidate(baseUrl);
    }

    for (final String baseUrl in candidates) {
      try {
        final http.Response response = await http
            .get(Uri.parse('$baseUrl/api/stock-catalog'))
            .timeout(const Duration(seconds: 20));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }
        final Map<String, dynamic> json =
            (jsonDecode(utf8.decode(response.bodyBytes))
                    as Map<dynamic, dynamic>)
                .cast<String, dynamic>();
        return (json['items'] as List<dynamic>? ?? <dynamic>[])
            .map(
              (dynamic item) => ProductItem.fromJson(
                (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
              ),
            )
            .where((ProductItem item) => item.moduleId == 'STOCK')
            .toList();
      } catch (error) {
        lastError = error;
      }
    }

    try {
      return await _loadBundledStockCatalog();
    } catch (error) {
      try {
        final ProductShellData bundledShell = await _loadBundledShell(
          await _loadActiveModuleIds(),
        );
        return bundledShell.items
            .where((ProductItem item) => item.moduleId == 'STOCK')
            .toList();
      } catch (bundledShellError) {
        throw StateError(
          'Catalogo STOCK indisponivel: $lastError; fallback asset: $error; shell: $bundledShellError',
        );
      }
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

  Future<List<ProductItem>> _loadBundledStockCatalog() async {
    final String catalogText = await rootBundle.loadString(
      _bundledStockRuntimeAsset,
    );
    final Map<String, dynamic> catalog =
        (jsonDecode(catalogText) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    return (catalog['items'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (dynamic item) => ProductItem.fromJson(
            (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
          ),
        )
        .where((ProductItem item) => item.moduleId == 'STOCK')
        .toList();
  }

  Future<ProductShellData> _withIntegratedStockCatalog(
    ProductShellData shell, {
    String? preferredBaseUrl,
  }) async {
    List<ProductItem> stockItems = <ProductItem>[];
    try {
      stockItems = await loadStockCatalog(preferredBaseUrl: preferredBaseUrl);
    } catch (_) {
      return shell;
    }

    if (stockItems.isEmpty) {
      return shell;
    }

    final List<ProductItem> nonStockItems = shell.items
        .where((ProductItem item) => item.moduleId != 'STOCK')
        .toList();
    final List<ProductItem> mergedItems = <ProductItem>[
      ...stockItems,
      ...nonStockItems,
    ];

    final int merchantCount = mergedItems
        .map(
          (ProductItem item) => item.supplierDisplayName.trim().isEmpty
              ? item.merchantName.trim()
              : item.supplierDisplayName.trim(),
        )
        .where((String value) => value.isNotEmpty)
        .toSet()
        .length;
    final int videoCount = mergedItems
        .where((ProductItem item) => item.hasVideo)
        .length;

    final Map<String, dynamic> rawData = Map<String, dynamic>.from(shell.rawData);
    rawData['items'] = mergedItems
        .map((ProductItem item) => item.raw)
        .toList(growable: false);

    return ProductShellData(
      baseUrl: shell.baseUrl,
      title: shell.title,
      subtitle: shell.subtitle,
      generatedAtUtc: shell.generatedAtUtc,
      modules: shell.modules,
      summary: ProductSummary(
        products: mergedItems.length,
        videos: videoCount,
        merchants: merchantCount,
        warehouses: shell.summary.warehouses,
      ),
      items: mergedItems,
      publicUrl: shell.publicUrl,
      rawData: rawData,
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
      if (Uri.base.path.startsWith('/product')) {
        addCandidate('$currentOrigin/product');
      }
    }
    if (_envBaseUrl.trim().isNotEmpty) {
      addCandidate(_envBaseUrl);
    }
    addCandidate(_releaseBaseUrl);

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
      final String publicUrl = publicRuntime['public_url'] as String? ?? '';
      if (publicUrl.isNotEmpty) {
        addCandidate('$publicUrl/product');
      }
    } catch (_) {
      // Mantem fallback fixo abaixo.
    }

    for (final String candidate in <String>[
      'https://admin.brasildesconto.com.br/product',
      'https://admin.brasildesconto.com.br',
      'http://10.0.2.2:8085/product',
      'http://10.0.2.2:8085',
      'http://127.0.0.1:8085/product',
      'http://127.0.0.1:8085',
      'http://localhost:8085/product',
      'http://localhost:8085',
      'http://192.168.1.2:8085/product',
      'http://192.168.1.2:8085',
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
