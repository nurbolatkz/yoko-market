class BannerItem {
  const BannerItem({
    required this.id,
    required this.title,
    required this.bgColor,
    this.badge,
    this.subtitle,
    this.textDark = false,
    this.imageUrl,
    this.originalPrice,
    this.discountPrice,
    this.discountBadge,
    this.promoType,
    this.actionType = 'none',
    this.actionValue,
    this.validUntil,
  });

  final String id;
  final String? badge;
  final String title;
  final String? subtitle;
  final String bgColor;
  final bool textDark;
  final String? imageUrl;
  final int? originalPrice;
  final int? discountPrice;
  final String? discountBadge;
  /// 'promotion' or 'giveaway' → tapping opens PromotionDetailScreen.
  /// null or 'banner' → follows actionType.
  final String? promoType;
  final String actionType;
  final String? actionValue;
  final DateTime? validUntil;

  bool get isPromoOrGiveaway =>
      promoType == 'promotion' || promoType == 'giveaway';

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    return BannerItem(
      id: '${json['id']}',
      badge: json['badge'] as String?,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      bgColor: json['bg_color'] as String? ?? '#1D2E81',
      textDark: json['text_dark'] as bool? ?? false,
      imageUrl: json['image_url'] as String?,
      originalPrice: _asNullableInt(json['original_price']),
      discountPrice: _asNullableInt(json['discount_price']),
      discountBadge: json['discount_badge'] as String?,
      promoType: json['promo_type'] as String?,
      actionType: json['action_type'] as String? ?? 'none',
      actionValue: json['action_value'] as String?,
      validUntil: _parseDateTime(json['valid_until']),
    );
  }
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null || '$value'.isEmpty) return null;
  try {
    return DateTime.parse('$value');
  } catch (_) {
    return null;
  }
}
