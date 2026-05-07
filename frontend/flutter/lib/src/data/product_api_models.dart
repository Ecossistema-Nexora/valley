class ProductModule {
  const ProductModule({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.badge,
  });

  factory ProductModule.fromJson(Map<String, dynamic> json) {
    return ProductModule(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      badge: json['badge'] as String? ?? '',
    );
  }

  final String id;
  final String label;
  final String subtitle;
  final String badge;
}

class ProductSummary {
  const ProductSummary({
    required this.products,
    required this.videos,
    required this.merchants,
    required this.warehouses,
  });

  factory ProductSummary.fromJson(Map<String, dynamic> json) {
    return ProductSummary(
      products: (json['products'] as num?)?.toInt() ?? 0,
      videos: (json['videos'] as num?)?.toInt() ?? 0,
      merchants: (json['merchants'] as num?)?.toInt() ?? 0,
      warehouses: (json['warehouses'] as num?)?.toInt() ?? 0,
    );
  }

  final int products;
  final int videos;
  final int merchants;
  final int warehouses;
}

class ProductItem {
  const ProductItem({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.brand,
    required this.category,
    required this.priceBrl,
    required this.compareAtBrl,
    required this.stock,
    required this.merchantName,
    required this.imageUrl,
    required this.videoUrl,
    required this.videoCount,
    required this.status,
    required this.tags,
    required this.ctaLabel,
    required this.ctaPath,
    required this.mediaPath,
    required this.description,
    required this.galleryUrls,
    required this.profileId,
    required this.raw,
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      id: json['id'] as String? ?? '',
      moduleId: json['module_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      category: json['category'] as String? ?? '',
      priceBrl: (json['price_brl'] as num?)?.toDouble() ?? 0,
      compareAtBrl: (json['compare_at_brl'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      merchantName: json['merchant_name'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      videoUrl: json['video_url'] as String? ?? '',
      videoCount: (json['video_count'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
      ctaLabel: json['cta_label'] as String? ?? 'Abrir',
      ctaPath: json['cta_path'] as String? ?? '',
      mediaPath: json['media_path'] as String? ?? '',
      description: json['description'] as String? ?? '',
      galleryUrls: (json['gallery_urls'] as List<dynamic>? ?? <dynamic>[])
          .cast<String>(),
      profileId: json['profile_id'] as String? ?? '',
      raw: Map<String, dynamic>.from(json),
    );
  }

  final String id;
  final String moduleId;
  final String title;
  final String brand;
  final String category;
  final double priceBrl;
  final double compareAtBrl;
  final int stock;
  final String merchantName;
  final String imageUrl;
  final String videoUrl;
  final int videoCount;
  final String status;
  final List<String> tags;
  final String ctaLabel;
  final String ctaPath;
  final String mediaPath;
  final String description;
  final List<String> galleryUrls;
  final String profileId;
  final Map<String, dynamic> raw;

  List<String> get mediaGallery {
    final List<String> merged = <String>[];
    void addImage(String value) {
      final String normalized = value.trim();
      if (normalized.isEmpty || merged.contains(normalized)) {
        return;
      }
      merged.add(normalized);
    }

    addImage(imageUrl);
    for (final String galleryUrl in galleryUrls) {
      addImage(galleryUrl);
    }
    return merged;
  }

  bool get hasVideo =>
      videoUrl.trim().isNotEmpty || mediaPath.trim().isNotEmpty;

  String get titlePtBr => _firstReadableString(<Object?>[
    raw['title_short_pt_br'],
    raw['title_resumo_pt_br'],
    raw['title_normalized_pt_br'],
    raw['title_pt_br'],
    title,
  ]);

  String get shortTitlePtBr => _truncateLabel(titlePtBr, 68);

  String get descriptionPtBr => _firstReadableString(<Object?>[
    raw['description_short_pt_br'],
    raw['description_resumo_pt_br'],
    raw['description_normalized_pt_br'],
    raw['description_pt_br'],
    description,
  ]);

  bool get checkoutReady =>
      raw['checkout_ready'] == true ||
      ctaPath.contains('/api/actions/checkout');

  String get collectionLabel => raw['collection_label'] as String? ?? brand;

  String get modelName => raw['model_name'] as String? ?? title;

  String get googleTaxonomyId =>
      raw['google_product_category_id']?.toString() ?? '';

  String get googleTaxonomyPath =>
      raw['google_product_category_path'] as String? ??
      raw['google_product_category'] as String? ??
      category;

  String get taxonomyLeaf {
    final List<String> segments = googleTaxonomyPath
        .split('>')
        .map((String segment) => segment.trim())
        .where((String segment) => segment.isNotEmpty)
        .toList();
    return segments.isEmpty ? category : segments.last;
  }

  String get priceBand => raw['price_band'] as String? ?? '';

  String get availabilityLabel =>
      raw['availability_label'] as String? ?? '$stock ofertas ativas';

  String get providerKey => raw['provider_key'] as String? ?? '';

  String get providerStatus => raw['provider_status'] as String? ?? '';

  String get supplierName => raw['supplier_name'] as String? ?? '';

  String get supplierType => raw['supplier_type'] as String? ?? '';

  String get supplierModel => raw['supplier_model'] as String? ?? '';

  String get channelLabel => raw['channel_label'] as String? ?? '';

  bool get shippingFree => raw['shipping_free'] == true;

  String get supplierDisplayName {
    if (supplierName.trim().isNotEmpty) {
      return supplierName.trim();
    }
    if (providerKey.trim().isNotEmpty) {
      return _humanizeProvider(providerKey);
    }
    if (merchantName.trim().isNotEmpty) {
      return merchantName.trim();
    }
    return 'Fornecedor integrado';
  }

  String get providerDisplayName {
    if (providerKey.trim().isNotEmpty) {
      return _humanizeProvider(providerKey);
    }
    return supplierDisplayName;
  }

  bool get supplierInternal =>
      (raw['supplier_visibility'] as String? ?? '') == 'internal';

  String _firstReadableString(List<Object?> values) {
    for (final Object? candidate in values) {
      final String normalized =
          candidate?.toString().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  String _truncateLabel(String value, int maxLength) {
    final String normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    final String slice = normalized.substring(0, maxLength - 1);
    final int lastSpace = slice.lastIndexOf(' ');
    final String shortened = lastSpace > 18
        ? slice.substring(0, lastSpace)
        : slice;
    return '${shortened.trim()}…';
  }

  String _humanizeProvider(String value) {
    final List<String> parts = value
        .split(RegExp(r'[_\-\s]+'))
        .map((String part) => part.trim())
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return value;
    }
    return parts
        .map(
          (String part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

class ProductAuthUser {
  const ProductAuthUser({
    required this.userId,
    required this.fullName,
    required this.displayName,
    required this.email,
    required this.cpf,
    required this.phone,
    required this.defaultDeliveryAddress,
    required this.primaryRole,
    required this.userKind,
    required this.accountStatus,
    required this.permissions,
    required this.isAdmin,
    required this.merchantSlug,
    required this.merchantCode,
  });

  factory ProductAuthUser.fromJson(Map<String, dynamic> json) {
    return ProductAuthUser(
      userId: json['user_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      cpf: json['cpf'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      defaultDeliveryAddress:
          (json['default_delivery_address'] as Map<dynamic, dynamic>? ??
                  const <dynamic, dynamic>{})
              .map(
                (dynamic key, dynamic value) =>
                    MapEntry(key.toString(), value.toString()),
              ),
      primaryRole: json['primary_role'] as String? ?? 'CUSTOMER',
      userKind: json['user_kind'] as String? ?? 'PF',
      accountStatus: json['account_status'] as String? ?? 'ACTIVE',
      permissions: (json['permissions'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .toList(growable: false),
      isAdmin: json['is_admin'] == true,
      merchantSlug: json['merchant_slug'] as String? ?? '',
      merchantCode: json['merchant_code'] as String? ?? '',
    );
  }

  final String userId;
  final String fullName;
  final String displayName;
  final String email;
  final String cpf;
  final String phone;
  final Map<String, String> defaultDeliveryAddress;
  final String primaryRole;
  final String userKind;
  final String accountStatus;
  final List<String> permissions;
  final bool isAdmin;
  final String merchantSlug;
  final String merchantCode;
}

class ProductAuthSession {
  const ProductAuthSession({
    required this.token,
    required this.sessionId,
    required this.expiresAt,
    required this.expiresInSeconds,
    required this.scope,
    required this.user,
  });

  factory ProductAuthSession.fromJson(Map<String, dynamic> json) {
    return ProductAuthSession(
      token: json['token'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      expiresAt: json['expires_at'] as String? ?? '',
      expiresInSeconds: (json['expires_in_seconds'] as num?)?.toInt() ?? 0,
      scope: json['scope'] as String? ?? 'product',
      user: ProductAuthUser.fromJson(
        (json['user'] as Map<dynamic, dynamic>? ?? const <dynamic, dynamic>{})
            .cast<String, dynamic>(),
      ),
    );
  }

  final String token;
  final String sessionId;
  final String expiresAt;
  final int expiresInSeconds;
  final String scope;
  final ProductAuthUser user;
}

class ProductAuthResult {
  const ProductAuthResult({
    required this.ok,
    required this.status,
    required this.message,
    required this.session,
    required this.detail,
  });

  final bool ok;
  final String status;
  final String message;
  final ProductAuthSession? session;
  final String detail;
}

class ProductShellData {
  const ProductShellData({
    required this.baseUrl,
    required this.title,
    required this.subtitle,
    required this.generatedAtUtc,
    required this.modules,
    required this.summary,
    required this.items,
    required this.publicUrl,
    required this.rawData,
  });

  final String baseUrl;
  final String title;
  final String subtitle;
  final String generatedAtUtc;
  final List<ProductModule> modules;
  final ProductSummary summary;
  final List<ProductItem> items;
  final String publicUrl;
  final Map<String, dynamic> rawData;
}

class ProductActionResult {
  const ProductActionResult({
    required this.ok,
    required this.status,
    required this.action,
    required this.message,
    required this.url,
    required this.payload,
  });

  final bool ok;
  final String status;
  final String action;
  final String message;
  final String url;
  final Map<String, dynamic> payload;
}

class ProductPurchase {
  const ProductPurchase({
    required this.purchaseId,
    required this.itemId,
    required this.title,
    required this.imageUrl,
    required this.priceBrl,
    required this.shippingCostBrl,
    required this.status,
    required this.createdAtUtc,
    required this.trackingCode,
    required this.trackingLabel,
    required this.trackingEta,
    required this.trackingEvents,
  });

  factory ProductPurchase.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> tracking =
        (json['tracking'] as Map<dynamic, dynamic>? ?? const <dynamic, dynamic>{})
            .cast<String, dynamic>();
    return ProductPurchase(
      purchaseId: json['purchase_id'] as String? ?? '',
      itemId: json['item_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Compra Valley',
      imageUrl: json['image_url'] as String? ?? '',
      priceBrl: (json['price_brl'] as num?)?.toDouble() ?? 0,
      shippingCostBrl: (json['shipping_cost_brl'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? '',
      createdAtUtc: json['created_at_utc'] as String? ?? '',
      trackingCode: tracking['tracking_code'] as String? ?? '',
      trackingLabel: tracking['status_label'] as String? ?? 'Pedido criado',
      trackingEta: tracking['eta'] as String? ?? 'Prazo do fornecedor',
      trackingEvents:
          (tracking['events'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<dynamic, dynamic>>()
              .map((Map<dynamic, dynamic> item) => item.cast<String, dynamic>())
              .toList(growable: false),
    );
  }

  final String purchaseId;
  final String itemId;
  final String title;
  final String imageUrl;
  final double priceBrl;
  final double shippingCostBrl;
  final String status;
  final String createdAtUtc;
  final String trackingCode;
  final String trackingLabel;
  final String trackingEta;
  final List<Map<String, dynamic>> trackingEvents;
}

class HomePreferences {
  const HomePreferences({
    required this.visibleModuleCodes,
    required this.favoriteModuleCodes,
    required this.updatedAtUtc,
  });

  factory HomePreferences.fromJson(Map<String, dynamic> json) {
    return HomePreferences(
      visibleModuleCodes:
          (json['visible_module_codes'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic item) => item.toString())
              .toList(growable: false),
      favoriteModuleCodes:
          (json['favorite_module_codes'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic item) => item.toString())
              .toList(growable: false),
      updatedAtUtc: json['updated_at_utc'] as String?,
    );
  }

  final List<String> visibleModuleCodes;
  final List<String> favoriteModuleCodes;
  final String? updatedAtUtc;
}

class HomeRecentAction {
  const HomeRecentAction({
    required this.id,
    required this.moduleCode,
    required this.status,
    required this.title,
    required this.detail,
    required this.occurredAtUtc,
    required this.amountLabel,
    required this.actionPath,
    required this.openModuleCode,
  });

  factory HomeRecentAction.fromJson(Map<String, dynamic> json) {
    return HomeRecentAction(
      id: json['id'] as String? ?? '',
      moduleCode: json['module_code'] as String? ?? '',
      status: json['status'] as String? ?? 'INFO',
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      occurredAtUtc: json['occurred_at_utc'] as String? ?? '',
      amountLabel: json['amount_label'] as String? ?? '',
      actionPath: json['action_path'] as String? ?? '',
      openModuleCode: json['open_module_code'] as String? ?? '',
    );
  }

  final String id;
  final String moduleCode;
  final String status;
  final String title;
  final String detail;
  final String occurredAtUtc;
  final String amountLabel;
  final String actionPath;
  final String openModuleCode;
}

class HomeRecommendation {
  const HomeRecommendation({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.moduleCode,
    required this.actionLabel,
    required this.reason,
    required this.priority,
    required this.actionPath,
    required this.openModuleCode,
  });

  factory HomeRecommendation.fromJson(Map<String, dynamic> json) {
    return HomeRecommendation(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      moduleCode: json['module_code'] as String? ?? '',
      actionLabel: json['action_label'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      priority: json['priority'] as String? ?? 'medium',
      actionPath: json['action_path'] as String? ?? '',
      openModuleCode: json['open_module_code'] as String? ?? '',
    );
  }

  final String id;
  final String title;
  final String subtitle;
  final String moduleCode;
  final String actionLabel;
  final String reason;
  final String priority;
  final String actionPath;
  final String openModuleCode;
}

class IdentitySignal {
  const IdentitySignal({
    required this.name,
    required this.status,
    required this.detail,
  });

  factory IdentitySignal.fromJson(Map<String, dynamic> json) {
    return IdentitySignal(
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      detail: json['detail'] as String? ?? '',
    );
  }

  final String name;
  final String status;
  final String detail;
}

class IdentityScoreData {
  const IdentityScoreData({
    required this.score,
    required this.level,
    required this.levelLabel,
    required this.summary,
    required this.anonymous,
    required this.signals,
  });

  factory IdentityScoreData.fromJson(Map<String, dynamic> json) {
    return IdentityScoreData(
      score: (json['score'] as num?)?.toInt() ?? 0,
      level: json['level'] as String? ?? 'baseline',
      levelLabel: json['level_label'] as String? ?? 'Baseline',
      summary: json['summary'] as String? ?? '',
      anonymous: json['anonymous'] == true,
      signals: (json['signals'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (dynamic item) => IdentitySignal.fromJson(
              (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
    );
  }

  final int score;
  final String level;
  final String levelLabel;
  final String summary;
  final bool anonymous;
  final List<IdentitySignal> signals;
}

class HomeMetricCard {
  const HomeMetricCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.accent,
  });

  factory HomeMetricCard.fromJson(Map<String, dynamic> json) {
    return HomeMetricCard(
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      accent: json['accent'] as String? ?? 'cyan',
    );
  }

  final String label;
  final String value;
  final String caption;
  final String accent;
}

class HomeProfileContext {
  const HomeProfileContext({
    required this.role,
    required this.roleLabel,
    required this.audienceKey,
    required this.focusTitle,
    required this.focusCaption,
    required this.preferredModuleCodes,
  });

  factory HomeProfileContext.fromJson(Map<String, dynamic> json) {
    return HomeProfileContext(
      role: json['role'] as String? ?? 'GUEST',
      roleLabel: json['role_label'] as String? ?? 'Convidado',
      audienceKey: json['audience_key'] as String? ?? 'guest',
      focusTitle: json['focus_title'] as String? ?? '',
      focusCaption: json['focus_caption'] as String? ?? '',
      preferredModuleCodes:
          (json['preferred_module_codes'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((dynamic item) => item.toString())
              .toList(growable: false),
    );
  }

  final String role;
  final String roleLabel;
  final String audienceKey;
  final String focusTitle;
  final String focusCaption;
  final List<String> preferredModuleCodes;
}

class HomeModuleSignal {
  const HomeModuleSignal({
    required this.moduleCode,
    required this.status,
    required this.headline,
    required this.detail,
    required this.accent,
  });

  factory HomeModuleSignal.fromJson(Map<String, dynamic> json) {
    return HomeModuleSignal(
      moduleCode: json['module_code'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      headline: json['headline'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      accent: json['accent'] as String? ?? 'cyan',
    );
  }

  final String moduleCode;
  final String status;
  final String headline;
  final String detail;
  final String accent;
}

class UserModuleTrail {
  const UserModuleTrail({
    required this.trailId,
    required this.createdAtUtc,
    required this.userId,
    required this.sessionId,
    required this.role,
    required this.moduleCode,
    required this.kind,
    required this.status,
    required this.headline,
    required this.detail,
    required this.provider,
    required this.itemId,
    required this.itemTitle,
    required this.domainAction,
    required this.journeyStage,
    required this.journeyKey,
    required this.primaryActionPath,
    required this.primaryActionLabel,
    required this.checkoutPath,
    required this.mediaPath,
    required this.interestPath,
    required this.openModuleCode,
  });

  factory UserModuleTrail.fromJson(Map<String, dynamic> json) {
    return UserModuleTrail(
      trailId: json['trail_id'] as String? ?? '',
      createdAtUtc: json['created_at_utc'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      role: json['role'] as String? ?? '',
      moduleCode: json['module_code'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      status: json['status'] as String? ?? 'INFO',
      headline: json['headline'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      itemId: json['item_id'] as String? ?? '',
      itemTitle: json['item_title'] as String? ?? '',
      domainAction: json['domain_action'] as String? ?? '',
      journeyStage: json['journey_stage'] as String? ?? '',
      journeyKey: json['journey_key'] as String? ?? '',
      primaryActionPath: json['primary_action_path'] as String? ?? '',
      primaryActionLabel: json['primary_action_label'] as String? ?? '',
      checkoutPath: json['checkout_path'] as String? ?? '',
      mediaPath: json['media_path'] as String? ?? '',
      interestPath: json['interest_path'] as String? ?? '',
      openModuleCode: json['open_module_code'] as String? ?? '',
    );
  }

  final String trailId;
  final String createdAtUtc;
  final String userId;
  final String sessionId;
  final String role;
  final String moduleCode;
  final String kind;
  final String status;
  final String headline;
  final String detail;
  final String provider;
  final String itemId;
  final String itemTitle;
  final String domainAction;
  final String journeyStage;
  final String journeyKey;
  final String primaryActionPath;
  final String primaryActionLabel;
  final String checkoutPath;
  final String mediaPath;
  final String interestPath;
  final String openModuleCode;
}

class ProductHomeData {
  const ProductHomeData({
    required this.ok,
    required this.anonymous,
    required this.persistable,
    required this.fetchedAtUtc,
    required this.profileContext,
    required this.preferences,
    required this.recentActions,
    required this.recommendations,
    required this.identityScore,
    required this.metrics,
    required this.moduleSignals,
    required this.userModuleTrails,
  });

  factory ProductHomeData.fromJson(Map<String, dynamic> json) {
    return ProductHomeData(
      ok: (json['status'] as String? ?? '') == 'ok',
      anonymous: json['anonymous'] == true,
      persistable: json['persistable'] == true,
      fetchedAtUtc: json['fetched_at_utc'] as String? ?? '',
      profileContext: HomeProfileContext.fromJson(
        (json['profile_context'] as Map<dynamic, dynamic>? ??
                const <dynamic, dynamic>{})
            .cast<String, dynamic>(),
      ),
      preferences: HomePreferences.fromJson(
        (json['preferences'] as Map<dynamic, dynamic>? ??
                const <dynamic, dynamic>{})
            .cast<String, dynamic>(),
      ),
      recentActions:
          (json['recent_actions'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (dynamic item) => HomeRecentAction.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
                ),
              )
              .toList(growable: false),
      recommendations:
          (json['recommendations'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (dynamic item) => HomeRecommendation.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
                ),
              )
              .toList(growable: false),
      identityScore: IdentityScoreData.fromJson(
        (json['identity_score'] as Map<dynamic, dynamic>? ??
                const <dynamic, dynamic>{})
            .cast<String, dynamic>(),
      ),
      metrics: (json['metrics'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (dynamic item) => HomeMetricCard.fromJson(
              (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      moduleSignals:
          (json['module_signals'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (dynamic item) => HomeModuleSignal.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
                ),
              )
              .toList(growable: false),
      userModuleTrails:
          (json['user_module_trails'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (dynamic item) => UserModuleTrail.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>(),
                ),
              )
              .toList(growable: false),
    );
  }

  final bool ok;
  final bool anonymous;
  final bool persistable;
  final String fetchedAtUtc;
  final HomeProfileContext profileContext;
  final HomePreferences preferences;
  final List<HomeRecentAction> recentActions;
  final List<HomeRecommendation> recommendations;
  final IdentityScoreData identityScore;
  final List<HomeMetricCard> metrics;
  final List<HomeModuleSignal> moduleSignals;
  final List<UserModuleTrail> userModuleTrails;
}
