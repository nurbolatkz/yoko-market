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
    this.actionLabel,
    this.validUntil,
    this.placement = 'hero',
    this.imageKind = 'ready',
    this.illustrationUrl,
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
  /// Human-readable CTA label from backend, e.g. "Выбрать подгузники".
  /// Falls back to generic label when null.
  final String? actionLabel;
  final DateTime? validUntil;

  /// Where Home shows the banner: `hero` (top carousel, default) or
  /// `special` (two-up «Специальные предложения» cards). Set by the backend.
  final String placement;

  bool get isSpecialOffer => placement == 'special';

  /// Format of [imageUrl]:
  /// - `ready` (default) — a finished banner with its text baked in; Flutter
  ///   must not draw the title on top of it.
  /// - `illustration` — an image without text; Flutter draws title, subtitle
  ///   and CTA from the banner fields.
  /// Proposed field (`image_kind`), not served by the backend yet — every
  /// production banner is therefore treated as `ready`.
  final String imageKind;

  bool get isIllustration => imageKind == 'illustration' && imageUrl != null;

  /// Transparent product cut-out for «Специальные предложения» cards — a
  /// separate asset from [imageUrl] (proposed `illustration_url`).
  final String? illustrationUrl;

  /// Whether the banner leads somewhere that exists in the app.
  bool get hasAction =>
      (actionType == 'category' || actionType == 'product') &&
      (actionValue?.isNotEmpty ?? false);

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
      actionLabel: json['action_label'] as String?,
      validUntil: _parseDateTime(json['valid_until']),
      placement: json['placement'] as String? ?? 'hero',
      imageKind: json['image_kind'] as String? ?? 'ready',
      illustrationUrl: json['illustration_url'] as String?,
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
