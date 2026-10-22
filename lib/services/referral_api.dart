import 'package:dio/dio.dart';

import '../config/app_config.dart';

class ReferralInfo {
  const ReferralInfo({
    required this.code,
    required this.bonusReferrer,
    required this.bonusUser,
  });

  final String code;
  final int bonusReferrer;
  final int bonusUser;

  factory ReferralInfo.fromJson(Map<String, dynamic> j) => ReferralInfo(
        code: j['referral_code'] as String? ?? '',
        bonusReferrer: (j['bonus_referrer'] as num?)?.toInt() ?? 500,
        bonusUser: (j['bonus_user'] as num?)?.toInt() ?? 300,
      );
}

class ReferralStats {
  const ReferralStats({
    required this.referredCount,
    required this.bonusesEarned,
    required this.team,
  });

  final int referredCount;
  final int bonusesEarned;
  final List<ReferralTeamMember> team;

  factory ReferralStats.fromJson(Map<String, dynamic> j) => ReferralStats(
        referredCount: (j['referred_count'] as num?)?.toInt() ?? 0,
        bonusesEarned: (j['bonuses_earned'] as num?)?.toInt() ?? 0,
        team: (j['team'] as List<dynamic>? ?? [])
            .map((e) => ReferralTeamMember.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ReferralTeamMember {
  const ReferralTeamMember({
    required this.name,
    required this.orders,
    required this.total,
  });

  final String name;
  final int orders;
  final int total;

  factory ReferralTeamMember.fromJson(Map<String, dynamic> j) =>
      ReferralTeamMember(
        name: j['name'] as String? ?? 'Пользователь',
        orders: (j['orders'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}

class ReferralApi {
  ReferralApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              responseType: ResponseType.json,
            ));

  final Dio _dio;

  Options _auth(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  Future<ReferralInfo> getOrCreateCode(String token) async {
    final resp = await _dio.post<dynamic>(
      '/profile/referral-code',
      options: _auth(token),
    );
    return ReferralInfo.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<ReferralStats> getStats(String token) async {
    final resp = await _dio.get<dynamic>(
      '/profile/referral-stats',
      options: _auth(token),
    );
    return ReferralStats.fromJson(resp.data as Map<String, dynamic>);
  }
}
