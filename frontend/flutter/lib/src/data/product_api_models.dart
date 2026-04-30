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

  bool get supplierInternal =>
      (raw['supplier_visibility'] as String? ?? '') == 'internal';
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
  });

  final bool ok;
  final String status;
  final String action;
  final String message;
  final String url;
}
