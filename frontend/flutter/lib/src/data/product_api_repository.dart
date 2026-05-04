import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  static const String _sessionTokenKey = 'valley.product.auth.session.v1';

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
    final String resolvedBaseUrl = await _resolveInteractiveBaseUrl(baseUrl);
    final Uri uri = Uri.parse('$resolvedBaseUrl$path');
    final http.Response response = await http
        .post(
          uri,
          headers: await _defaultHeaders(),
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

  Future<ProductAuthResult> register({
    required String baseUrl,
    required String fullName,
    required String displayName,
    required String email,
    required String password,
    required String role,
  }) async {
    final String resolvedBaseUrl = await _resolveInteractiveBaseUrl(baseUrl);
    final http.Response response = await http
        .post(
          Uri.parse('$resolvedBaseUrl/api/auth/register'),
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, dynamic>{
            'full_name': fullName,
            'display_name': displayName,
            'email': email,
            'password': password,
            'role': role,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return _parseAuthResult(response, persistSession: false);
  }

  Future<ProductAuthResult> login({
    required String baseUrl,
    required String identifier,
    required String password,
    String scope = 'product',
  }) async {
    final String resolvedBaseUrl = await _resolveInteractiveBaseUrl(baseUrl);
    final http.Response response = await http
        .post(
          Uri.parse('$resolvedBaseUrl/api/auth/login'),
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, dynamic>{
            'identifier': identifier,
            'password': password,
            'scope': scope,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return _parseAuthResult(response, persistSession: true);
  }

  Future<ProductAuthResult> restoreSession({
    required String baseUrl,
    String scope = 'product',
  }) async {
    final String token = await _readSessionToken();
    if (token.isEmpty) {
      return const ProductAuthResult(
        ok: false,
        status: 'anonymous',
        message: 'Nenhuma sessão ativa.',
        session: null,
        detail: '',
      );
    }

    final String resolvedBaseUrl = await _resolveInteractiveBaseUrl(baseUrl);
    final http.Response response = await http
        .get(
          Uri.parse('$resolvedBaseUrl/api/auth/session?scope=$scope'),
          headers: await _defaultHeaders(tokenOverride: token),
        )
        .timeout(const Duration(seconds: 20));
    final Map<String, dynamic> json =
        (jsonDecode(utf8.decode(response.bodyBytes)) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    if ((json['status'] as String? ?? '') != 'ok') {
      await clearSession();
      return ProductAuthResult(
        ok: false,
        status: json['status'] as String? ?? 'anonymous',
        message: json['detail'] as String? ?? 'Sessão expirada.',
        session: null,
        detail: json['detail'] as String? ?? '',
      );
    }

    final ProductAuthSession session = ProductAuthSession.fromJson(
      (json['session'] as Map<dynamic, dynamic>? ?? const <dynamic, dynamic>{})
          .cast<String, dynamic>(),
    );
    await _persistSessionToken(session.token.isNotEmpty ? session.token : token);
    return ProductAuthResult(
      ok: true,
      status: 'ok',
      message: 'Sessão restaurada.',
      session: session,
      detail: '',
    );
  }

  Future<void> logout({
    required String baseUrl,
  }) async {
    final String resolvedBaseUrl = await _resolveInteractiveBaseUrl(baseUrl);
    try {
      await http
          .post(
            Uri.parse('$resolvedBaseUrl/api/auth/logout'),
            headers: await _defaultHeaders(),
          )
          .timeout(const Duration(seconds: 20));
    } finally {
      await clearSession();
    }
  }

  Future<void> clearSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionTokenKey);
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
      'https://brasildesconto.com.br/product',
      'https://brasildesconto.com.br',
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

  Future<ProductAuthResult> _parseAuthResult(
    http.Response response, {
    required bool persistSession,
  }) async {
    final Map<String, dynamic> json =
        (jsonDecode(utf8.decode(response.bodyBytes)) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    final ProductAuthSession? session =
        json['session'] is Map<dynamic, dynamic>
        ? ProductAuthSession.fromJson(
            (json['session'] as Map<dynamic, dynamic>).cast<String, dynamic>(),
          )
        : null;
    if (persistSession) {
      if (session != null && session.token.isNotEmpty) {
        await _persistSessionToken(session.token);
      } else if (response.statusCode >= 400) {
        await clearSession();
      }
    }
    return ProductAuthResult(
      ok: response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (json['status'] as String? ?? '') == 'ok',
      status: json['status'] as String? ?? 'unknown',
      message:
          json['message'] as String? ??
          json['detail'] as String? ??
          'Operação concluída.',
      session: session,
      detail: json['detail'] as String? ?? '',
    );
  }

  Future<String> _resolveInteractiveBaseUrl(String preferredBaseUrl) async {
    final String normalized = _normalizeBaseUrl(preferredBaseUrl);
    if (normalized.startsWith('http')) {
      return normalized;
    }
    final List<String> candidates = await _candidateBaseUrls();
    for (final String candidate in candidates) {
      if (candidate.startsWith('http')) {
        return candidate;
      }
    }
    throw StateError('Nenhuma base URL HTTP disponível para autenticação Valley.');
  }

  Future<Map<String, String>> _defaultHeaders({String? tokenOverride}) async {
    final String token = tokenOverride ?? await _readSessionToken();
    return <String, String>{
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (token.isNotEmpty) 'X-Valley-Session': token,
    };
  }

  Future<void> _persistSessionToken(String token) async {
    if (token.trim().isEmpty) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionTokenKey, token.trim());
  }

  Future<String> _readSessionToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionTokenKey)?.trim() ?? '';
  }
}
