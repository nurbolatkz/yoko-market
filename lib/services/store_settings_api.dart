import 'package:dio/dio.dart';

import '../config/app_config.dart';

// ── Model ──────────────────────────────────────────────────────────────────────

class StoreSettings {
  const StoreSettings({required this.deliveryFreeFrom});
  final int deliveryFreeFrom;
}

// ── Abstract interface ─────────────────────────────────────────────────────────

abstract interface class StoreSettingsApi {
  Future<StoreSettings> getSettings();
}

// ── HTTP implementation ────────────────────────────────────────────────────────

class HttpStoreSettingsApi implements StoreSettingsApi {
  HttpStoreSettingsApi({Dio? dio})
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
  Future<StoreSettings> getSettings() async {
    try {
      final response = await _dio.get<dynamic>('/settings/delivery');
      final j = response.data as Map<String, dynamic>? ?? {};
      final raw = j['free_delivery_from'];
      final deliveryFreeFrom = raw is num ? raw.toInt() : 10000;
      return StoreSettings(deliveryFreeFrom: deliveryFreeFrom);
    } catch (_) {
      return const StoreSettings(deliveryFreeFrom: 10000);
    }
  }
}

// ── Mock implementation ────────────────────────────────────────────────────────

class MockStoreSettingsApi implements StoreSettingsApi {
  @override
  Future<StoreSettings> getSettings() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return const StoreSettings(deliveryFreeFrom: 10000);
  }
}

// ── Factory ────────────────────────────────────────────────────────────────────

StoreSettingsApi createStoreSettingsApi() =>
    AppConfig.mockStoreSettings ? MockStoreSettingsApi() : HttpStoreSettingsApi();
