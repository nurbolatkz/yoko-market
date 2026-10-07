import '../config/app_config.dart';

class Product {
  final String id;
  final String title;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final String packageInfo;
  final bool inStock;
  final int stockQuantity;
  final double rating;

  Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.packageInfo,
    this.inStock = true,
    this.stockQuantity = 1,
    this.rating = 4.5,
  });

  factory Product.fromApiJson(Map<String, dynamic> json) {
    final stockQuantity = _asInt(
      json['stock_qty'] ?? (json['in_stock'] == false ? 0 : 1),
    );
    final salePrice = _asNullableDouble(
      json['promo_price'] ?? json['sale_price'],
    );

    return Product(
      id: '${json['id']}',
      title: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: salePrice ?? _asDouble(json['price']),
      imageUrl: _firstImageUrl(json) ?? '',
      category: json['category'] as String? ?? '',
      packageInfo: json['size'] != null && json['size'] != 'ONE'
          ? '${json['size']}'
          : '',
      inStock: stockQuantity > 0 && json['is_active'] != false,
      stockQuantity: stockQuantity,
      rating: _asDouble(json['rating']),
    );
  }
}

String? _firstImageUrl(Map<String, dynamic> json) {
  final candidates = <dynamic>[
    json['hero_url'],
    json['image_url'],
    if (json['images'] is List) ...(json['images'] as List),
    json['photo_file_id'],
  ];

  for (final candidate in candidates) {
    final raw = candidate is Map<String, dynamic>
        ? candidate['url']
        : candidate;
    final url = _absoluteUrl(raw);
    if (url != null) return url;
  }
  return null;
}

String? _absoluteUrl(dynamic value) {
  if (value == null || '$value'.isEmpty) return null;
  final url = '$value';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (url.startsWith('/opt/back/media/')) {
    return 'https://yoko-sun.kz/media/${url.substring('/opt/back/media/'.length)}';
  }
  if (url.startsWith('/')) return '${AppConfig.apiOrigin}$url';
  return '${AppConfig.apiOrigin}/$url';
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  return _asDouble(value);
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}
