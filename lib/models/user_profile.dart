class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    this.fullName,
    this.address,
    this.bonusBalance = 0,
    this.loyaltyTier,
    this.loyaltyTierLabel,
    this.isRegistered = false,
  });

  final String id;
  final String phone;
  final String? fullName;
  final String? address;
  final int bonusBalance;
  final String? loyaltyTier;
  final String? loyaltyTierLabel;
  final bool isRegistered;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    fullName: json['full_name'] as String?,
    address: json['address'] as String?,
    bonusBalance: (json['bonus_balance'] as num?)?.toInt() ?? 0,
    loyaltyTier: json['loyalty_tier'] as String?,
    loyaltyTierLabel: json['loyalty_tier_label'] as String?,
    isRegistered: json['is_registered'] as bool? ?? false,
  );

  String get displayName => fullName?.isNotEmpty == true ? fullName! : phone;
}
