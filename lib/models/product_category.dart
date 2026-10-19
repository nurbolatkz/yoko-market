import '../config/app_config.dart';

class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    this.slug,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String? slug;
  final String? imageUrl;

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: '${json['id']}',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String?,
      imageUrl: _resolveImageUrl(json['image']),
    );
  }
}

String? _resolveImageUrl(dynamic value) {
  if (value == null || '$value'.isEmpty) return null;
  final url = '$value';
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (url.startsWith('/')) return '${AppConfig.apiOrigin}$url';
  return null;
}
