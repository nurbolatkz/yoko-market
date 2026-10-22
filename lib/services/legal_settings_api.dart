import 'package:dio/dio.dart';

import '../config/app_config.dart';

class LegalUrls {
  const LegalUrls({required this.privacyUrl, required this.termsUrl});

  final String privacyUrl;
  final String termsUrl;

  bool get hasAny => privacyUrl.isNotEmpty || termsUrl.isNotEmpty;

  factory LegalUrls.fromJson(Map<String, dynamic> j) => LegalUrls(
        privacyUrl: j['privacy_url'] as String? ?? '',
        termsUrl: j['terms_url'] as String? ?? '',
      );
}

class LegalSettingsApi {
  LegalSettingsApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              responseType: ResponseType.json,
            ));

  final Dio _dio;

  Future<LegalUrls> getLegalUrls() async {
    final resp = await _dio.get<dynamic>('/settings/legal');
    return LegalUrls.fromJson(resp.data as Map<String, dynamic>);
  }
}
