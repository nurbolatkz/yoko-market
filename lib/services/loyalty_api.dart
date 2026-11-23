import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/loyalty.dart';
import 'api_client.dart';

/// Loyalty programme rules (AGENTS.md §9). Screens read every number —
/// tiers, max bonus payment, sign-up / referral bonuses, free-delivery
/// threshold — from here and never hardcode them.
///
/// Implementation is picked by `--dart-define=MOCK_LOYALTY` (default `true`
/// until the backend serves the monthly-cashback rules).
abstract class LoyaltyApi {
  factory LoyaltyApi() =>
      AppConfig.mockLoyalty ? MockLoyaltyApi() : HttpLoyaltyApi();

  Future<LoyaltyRules> getRules();
}

/// `GET /loyalty/rules` (public). Parses both the new contract shape and the
/// legacy one served today.
class HttpLoyaltyApi implements LoyaltyApi {
  HttpLoyaltyApi({Dio? dio}) : _dio = dio ?? ApiClient.create();

  final Dio _dio;

  @override
  Future<LoyaltyRules> getRules() async {
    final resp = await _dio.get<dynamic>('/loyalty/rules');
    return LoyaltyRules.fromJson(resp.data as Map<String, dynamic>);
  }
}

/// Figma numbers: 3 % from 50 000 ₸, 5 % from 100 000 ₸, 10 % from
/// 200 000 ₸ a month; up to 100 % of an order payable with YoCoin;
/// 1 000 YoCoin for sign-up, 300 per invited friend; free delivery from
/// 10 000 ₸.
class MockLoyaltyApi implements LoyaltyApi {
  MockLoyaltyApi({this.delay = const Duration(milliseconds: 500)});

  final Duration delay;

  static const rulesJson = <String, dynamic>{
    'tiers': [
      {'min_monthly_spend': 50000, 'percent': 3, 'label': 'от 50 000 ₸'},
      {'min_monthly_spend': 100000, 'percent': 5, 'label': 'от 100 000 ₸'},
      {'min_monthly_spend': 200000, 'percent': 10, 'label': 'от 200 000 ₸'},
    ],
    'max_pay_with_bonus_pct': 100,
    'registration_bonus': 1000,
    'referral_bonus': 300,
    'free_delivery_threshold': 10000,
  };

  static final rules = LoyaltyRules.fromJson(rulesJson);

  @override
  Future<LoyaltyRules> getRules() async {
    await Future<void>.delayed(delay);
    return rules;
  }
}
