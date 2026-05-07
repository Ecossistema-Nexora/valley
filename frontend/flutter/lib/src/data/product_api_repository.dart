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
      'http://100.109.240.100:8085';
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
        return await _withBundledStockCatalog(bundledShell);
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
        final ProductShellData shell = _parseShell(
          baseUrl,
          json,
          activeModuleIds,
        );
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
      return await _withBundledStockCatalog(bundledShell);
    } catch (error) {
      try {
        return await _loadEmergencyBundledShell(activeModuleIds);
      } catch (fallbackError) {
        throw StateError(
          'Servidor Valley indisponivel: $lastError; fallback: $error; emergencia: $fallbackError',
        );
      }
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
    Map<String, dynamic> body = const <String, dynamic>{},
  }) async {
    final String resolvedBaseUrl = await _resolveInteractiveBaseUrl(baseUrl);
    final Uri uri = Uri.parse('$resolvedBaseUrl$path');
    final http.Response response = await http
        .post(uri, headers: await _defaultHeaders(), body: jsonEncode(body))
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
      payload: payload,
    );
  }

  Future<ProductAuthResult> register({
    required String baseUrl,
    required String fullName,
    required String displayName,
    required String email,
    required String password,
    required String role,
    required String cpf,
    required String phone,
    required Map<String, String> defaultDeliveryAddress,
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
            'cpf': cpf,
            'phone': phone,
            'postal_code': defaultDeliveryAddress['postal_code'] ?? '',
            'street': defaultDeliveryAddress['street'] ?? '',
            'number': defaultDeliveryAddress['number'] ?? '',
            'complement': defaultDeliveryAddress['complement'] ?? '',
            'neighborhood': defaultDeliveryAddress['neighborhood'] ?? '',
            'city': defaultDeliveryAddress['city'] ?? '',
            'state': defaultDeliveryAddress['state'] ?? '',
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
    await _persistSessionToken(
      session.token.isNotEmpty ? session.token : token,
    );
    return ProductAuthResult(
      ok: true,
      status: 'ok',
      message: 'Sessão restaurada.',
      session: session,
      detail: '',
    );
  }

  Future<void> logout({required String baseUrl}) async {
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

  Future<ProductHomeData> loadHome({String baseUrl = ''}) async {
    final String resolvedBaseUrl = await _resolveInteractiveBaseUrl(baseUrl);
    final http.Response response = await http
        .get(
          Uri.parse('$resolvedBaseUrl/api/me/home'),
          headers: await _defaultHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    final Map<String, dynamic> json =
        (jsonDecode(utf8.decode(response.bodyBytes)) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    return ProductHomeData.fromJson(json);
  }

  Future<List<HomeRecentAction>> loadRecentActions({
    String baseUrl = '',
  }) async {
    final String resolvedBaseUrl = await _resolveInteractiveBaseUrl(baseUrl);
    final http.Response response = await http
        .get(
          Uri.parse('$resolvedBaseUrl/api/me/recent-actions'),
          headers: await _defaultHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    final Map<String, dynamic> json =
        (jsonDecode(utf8.decode(response.bodyBytes)) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    return (json['recent_actions'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (dynamic item) => HomeRecentAction.fromJson(
            (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

  Future<List<HomeRecommendation>> loadRecommendations({
    String baseUrl = '',
  }) async {
    final String resolvedBaseUrl = await _resolveInteractiveBaseUrl(baseUrl);
    final http.Response response = await http
        .get(
          Uri.parse('$resolvedBaseUrl/api/me/recommendations'),
          headers: await _defaultHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    final Map<String, dynamic> json =
        (jsonDecode(utf8.decode(response.bodyBytes)) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    return (json['recommendations'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (dynamic item) => HomeRecommendation.fromJson(
            (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

  Future<IdentityScoreData> loadIdentityScore({String baseUrl = ''}) async {
    final String resolvedBaseUrl = await _resolveInteractiveBaseUrl(baseUrl);
    final http.Response response = await http
        .get(
          Uri.parse('$resolvedBaseUrl/api/me/identity-score'),
          headers: await _defaultHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    final Map<String, dynamic> json =
        (jsonDecode(utf8.decode(response.bodyBytes)) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    return IdentityScoreData.fromJson(json);
  }

  Future<List<ProductPurchase>> loadPurchases({String baseUrl = ''}) async {
    final String resolvedBaseUrl = await _resolveInteractiveBaseUrl(baseUrl);
    final http.Response response = await http
        .get(
          Uri.parse('$resolvedBaseUrl/api/me/purchases'),
          headers: await _defaultHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    final Map<String, dynamic> json =
        (jsonDecode(utf8.decode(response.bodyBytes)) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    return (json['purchases'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> item) =>
              ProductPurchase.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> loadNotifications({
    String baseUrl = '',
  }) async {
    final String resolvedBaseUrl = await _resolveInteractiveBaseUrl(baseUrl);
    final http.Response response = await http
        .get(
          Uri.parse('$resolvedBaseUrl/api/me/notifications'),
          headers: await _defaultHeaders(),
        )
        .timeout(const Duration(seconds: 20));
    final Map<String, dynamic> json =
        (jsonDecode(utf8.decode(response.bodyBytes)) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    return (json['notifications'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> item) => item.cast<String, dynamic>())
        .toList(growable: false);
  }

  Future<HomePreferences> saveHomePreferences({
    String baseUrl = '',
    required List<String> visibleModuleCodes,
    List<String> favoriteModuleCodes = const <String>[],
  }) async {
    final String resolvedBaseUrl = await _resolveInteractiveBaseUrl(baseUrl);
    final http.Response response = await http
        .put(
          Uri.parse('$resolvedBaseUrl/api/me/home/preferences'),
          headers: await _defaultHeaders(),
          body: jsonEncode(<String, dynamic>{
            'visible_module_codes': visibleModuleCodes,
            'favorite_module_codes': favoriteModuleCodes,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final Map<String, dynamic> json =
        (jsonDecode(utf8.decode(response.bodyBytes)) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        json['detail'] as String? ??
            'Falha ao persistir preferências da home no servidor.',
      );
    }
    return HomePreferences.fromJson(
      (json['preferences'] as Map<dynamic, dynamic>? ??
              const <dynamic, dynamic>{})
          .cast<String, dynamic>(),
    );
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
    final List<Map<String, String>> fallbackModules = _fallbackProductModules(
      activeModuleIds,
    );
    if ((catalog['modules'] as List<dynamic>? ?? <dynamic>[]).isEmpty) {
      catalog['modules'] = fallbackModules;
    }
    if ((catalog['module_screens'] as List<dynamic>? ?? <dynamic>[]).isEmpty) {
      catalog['module_screens'] = fallbackModules
          .map(
            (Map<String, String> module) => <String, String>{
              'module_id': module['id'] ?? '',
              'title': module['label'] ?? '',
              'headline': module['subtitle'] ?? '',
              'summary': module['subtitle'] ?? '',
            },
          )
          .toList(growable: false);
    }
    return _parseShell(_releaseBaseUrl, catalog, activeModuleIds);
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
          (dynamic item) => ProductItem.fromJson(_enrichBundledStockItem(item)),
        )
        .where((ProductItem item) => item.moduleId == 'STOCK')
        .toList();
  }

  Future<ProductShellData> _loadEmergencyBundledShell(
    Set<String> activeModuleIds,
  ) async {
    final List<ProductItem> stockItems = await _loadBundledStockCatalog();
    final List<ProductModule> modules = _fallbackProductModules(
      activeModuleIds,
    ).map(ProductModule.fromJson).toList(growable: false);
    final int merchantCount = stockItems
        .map((ProductItem item) => item.supplierDisplayName)
        .where((String value) => value.trim().isNotEmpty)
        .toSet()
        .length;
    final Map<String, dynamic> rawData = <String, dynamic>{
      'status': 'ok',
      'service': 'valley-product-bundled',
      'modules': modules
          .map(
            (ProductModule module) => <String, String>{
              'id': module.id,
              'label': module.label,
              'subtitle': module.subtitle,
              'badge': module.badge,
            },
          )
          .toList(growable: false),
      'module_screens': modules
          .map(
            (ProductModule module) => <String, String>{
              'module_id': module.id,
              'title': module.label,
              'headline': module.subtitle,
              'summary': module.subtitle,
            },
          )
          .toList(growable: false),
      'items': stockItems.map((ProductItem item) => item.raw).toList(),
    };
    return ProductShellData(
      baseUrl: _releaseBaseUrl,
      title: 'Valley',
      subtitle: 'Catalogo embarcado com checkout publico e operacao remota.',
      generatedAtUtc: '',
      modules: modules,
      summary: ProductSummary(
        products: stockItems.length,
        videos: stockItems.where((ProductItem item) => item.hasVideo).length,
        merchants: merchantCount,
        warehouses: 0,
      ),
      items: stockItems,
      publicUrl: _releaseBaseUrl,
      rawData: rawData,
    );
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

    return _mergeStockItems(shell, stockItems);
  }

  Future<ProductShellData> _withBundledStockCatalog(
    ProductShellData shell,
  ) async {
    try {
      final List<ProductItem> stockItems = await _loadBundledStockCatalog();
      if (stockItems.isEmpty) {
        return shell;
      }
      return _mergeStockItems(shell, stockItems);
    } catch (_) {
      return shell;
    }
  }

  ProductShellData _mergeStockItems(
    ProductShellData shell,
    List<ProductItem> stockItems,
  ) {
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

    final Map<String, dynamic> rawData = Map<String, dynamic>.from(
      shell.rawData,
    );
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
      'http://100.109.240.100:8085',
      'http://100.109.240.100:8085/product',
      'http://valley-codex.tailb44596.ts.net:8085',
      'http://valley-codex.tailb44596.ts.net:8085/product',
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

  List<Map<String, String>> _fallbackProductModules(
    Set<String> activeModuleIds,
  ) {
    const List<Map<String, String>> modules = <Map<String, String>>[
      <String, String>{
        'id': 'MARKETPLACE',
        'label': 'Marketplace',
        'subtitle': 'Vitrine comercial com ofertas e conversao pronta.',
        'badge': 'LIVE',
      },
      <String, String>{
        'id': 'STOCK',
        'label': 'Stock',
        'subtitle': 'Catalogo importado, estoque e margem operacional.',
        'badge': 'SYNC',
      },
      <String, String>{
        'id': 'CHAT',
        'label': 'Chat',
        'subtitle': 'Atendimento e negociacao com Helena.',
        'badge': 'ON',
      },
      <String, String>{
        'id': 'PAY',
        'label': 'Checkout',
        'subtitle': 'Pagamento seguro conectado ao runtime publico.',
        'badge': 'PAY',
      },
    ];
    return modules
        .where(
          (Map<String, String> module) =>
              activeModuleIds.contains(module['id']),
        )
        .toList(growable: false);
  }

  Map<String, dynamic> _enrichBundledStockItem(dynamic item) {
    final Map<String, dynamic> raw = (item as Map<dynamic, dynamic>)
        .cast<String, dynamic>();
    final String itemId = (raw['id'] as String? ?? '').trim();
    final Map<String, dynamic> enriched = Map<String, dynamic>.from(raw);
    if (itemId.isNotEmpty) {
      enriched['cta_path'] =
          raw['cta_path'] as String? ?? '/api/actions/checkout?item_id=$itemId';
      enriched['cta_label'] = raw['cta_label'] as String? ?? 'Abrir pagamento';
      enriched['checkout_ready'] =
          raw['checkout_ready'] == true ||
          (enriched['cta_path'] as String).contains('/api/actions/checkout');
      enriched['payment_provider'] =
          raw['payment_provider'] as String? ?? 'mercado_pago';
      enriched['publication_status'] =
          raw['publication_status'] as String? ?? 'approved';
      enriched['publication_status_label'] =
          raw['publication_status_label'] as String? ??
          'Aprovado automaticamente';
    }
    return enriched;
  }

  Future<ProductAuthResult> _parseAuthResult(
    http.Response response, {
    required bool persistSession,
  }) async {
    final Map<String, dynamic> json =
        (jsonDecode(utf8.decode(response.bodyBytes)) as Map<dynamic, dynamic>)
            .cast<String, dynamic>();
    final ProductAuthSession? session = json['session'] is Map<dynamic, dynamic>
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
      ok:
          response.statusCode >= 200 &&
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
    if (normalized.startsWith('http') && !_isLocalBaseUrl(normalized)) {
      return normalized;
    }
    final List<String> candidates = await _candidateBaseUrls();
    for (final String candidate in candidates) {
      if (candidate.startsWith('http') && !_isLocalBaseUrl(candidate)) {
        return candidate;
      }
    }
    if (normalized.startsWith('http')) {
      return normalized;
    }
    throw StateError(
      'Nenhuma base URL HTTP disponível para autenticação Valley.',
    );
  }

  bool _isLocalBaseUrl(String value) {
    final Uri? uri = Uri.tryParse(value);
    final String host = uri?.host.toLowerCase() ?? '';
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '10.0.2.2' ||
        host.startsWith('192.168.');
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
