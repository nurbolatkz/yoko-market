import '../models/user_profile.dart';
import 'auth_service.dart';

/// Dev-only AuthService that returns a fixed mock profile instantly.
/// Activated via --dart-define=UI_PREVIEW=true; never shipped in release builds.
class PreviewAuthService extends AuthService {
  static final _mockUser = UserProfile(
    id: 'preview',
    phone: '+77012345678',
    fullName: 'Айгерим Бекова',
    bonusBalance: 4200,
    loyaltyTier: null,
    loyaltyTierLabel: null,
    isRegistered: true,
  );

  @override
  Future<bool> hasSession() async => true;

  @override
  Future<String?> tryRefresh() async => 'preview-token';

  @override
  Future<UserProfile?> getProfile() async => _mockUser;

  @override
  Future<String?> getAccessToken() async => 'preview-token';
}
