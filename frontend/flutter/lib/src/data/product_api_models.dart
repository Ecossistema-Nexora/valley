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
  });

  final String baseUrl;
  final String title;
  final String subtitle;
  final String generatedAtUtc;
  final List<ProductModule> modules;
  final ProductSummary summary;
  final List<ProductItem> items;
  final String publicUrl;
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
