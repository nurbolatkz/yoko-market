import 'package:dio/dio.dart';

import '../config/app_config.dart';

// ── Model ──────────────────────────────────────────────────────────────────────

class LoyaltyRules {
  const LoyaltyRules({required this.defaultCashbackPct});
  final int defaultCashbackPct;
}

// ── Abstract interface ─────────────────────────────────────────────────────────

abstract interface class LoyaltyApi {
  Future<LoyaltyRules> getRules();
}

// ── HTTP implementation ────────────────────────────────────────────────────────

class HttpLoyaltyApi implements LoyaltyApi {
  HttpLoyaltyApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                responseType: ResponseType.json,
              ),
            );

  final Dio _dio;

  @override
  Future<LoyaltyRules> getRules() async {
    final response = await _dio.get<dynamic>('/loyalty/rules');
    final j = response.data as Map<String, dynamic>? ?? {};
    final accrual = j['accrual'] as Map<String, dynamic>? ?? {};
    final pct = accrual['default_pct'];
    final defaultCashbackPct = pct is num ? pct.toInt() : 0;
    return LoyaltyRules(defaultCashbackPct: defaultCashbackPct);
  }
}

// ── Mock implementation ────────────────────────────────────────────────────────

class MockLoyaltyApi implements LoyaltyApi {
  @override
  Future<LoyaltyRules> getRules() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const LoyaltyRules(defaultCashbackPct: 3);
  }
}

// ── Factory ────────────────────────────────────────────────────────────────────

LoyaltyApi createLoyaltyApi() =>
    AppConfig.mockLoyalty ? MockLoyaltyApi() : HttpLoyaltyApi();
