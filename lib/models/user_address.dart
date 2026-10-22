class UserAddress {
  const UserAddress({
    required this.id,
    required this.cityCode,
    required this.cityName,
    required this.street,
    required this.house,
    required this.aptOffice,
    required this.comment,
    required this.isDefault,
  });

  final String id;
  final String cityCode;
  final String cityName;
  final String street;
  final String house;
  final String aptOffice;
  final String comment;
  final bool isDefault;

  String get assembledText {
    final parts = <String>[];
    if (cityName.isNotEmpty) parts.add('г. $cityName');
    if (street.isNotEmpty) parts.add(street);
    if (house.isNotEmpty) parts.add('д. $house');
    if (aptOffice.isNotEmpty) parts.add(aptOffice);
    if (comment.isNotEmpty) parts.add(comment);
    return parts.join(', ');
  }

  factory UserAddress.fromJson(Map<String, dynamic> j) => UserAddress(
        id: j['id'] as String,
        cityCode: j['city_code'] as String? ?? '',
        cityName: j['city_name'] as String? ?? '',
        street: j['street'] as String? ?? '',
        house: j['house'] as String? ?? '',
        aptOffice: j['apt_office'] as String? ?? '',
        comment: j['comment'] as String? ?? '',
        isDefault: j['is_default'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'city_code': cityCode,
        'city_name': cityName,
        'street': street,
        'house': house,
        'apt_office': aptOffice.isEmpty ? null : aptOffice,
        'comment': comment.isEmpty ? null : comment,
        'is_default': isDefault,
      };

  UserAddress copyWith({
    String? id,
    String? cityCode,
    String? cityName,
    String? street,
    String? house,
    String? aptOffice,
    String? comment,
    bool? isDefault,
  }) =>
      UserAddress(
        id: id ?? this.id,
        cityCode: cityCode ?? this.cityCode,
        cityName: cityName ?? this.cityName,
        street: street ?? this.street,
        house: house ?? this.house,
        aptOffice: aptOffice ?? this.aptOffice,
        comment: comment ?? this.comment,
        isDefault: isDefault ?? this.isDefault,
      );
}
