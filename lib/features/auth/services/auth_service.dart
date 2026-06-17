import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';
import '../models/register_request.dart';
import '../models/user_profile.dart';

/// Handles authentication against POST /api/auth/* endpoints.
///
/// Example:
///   final profile = await AuthService.login(LoginRequest(email: '...', password: '...'));
///   final me = await AuthService.me();
///   await AuthService.logout();
class AuthService {
  AuthService._();

  /// Registers a new account.
  /// Returns the created user profile (or the one returned by the backend).
  static Future<UserProfile> register(RegisterRequest request) async {
    final data = await ApiClient.post(
      '/api/auth/register',
      body: request.toJson(),
    );
    final json = data as Map<String, dynamic>;

    // Save token if registration auto-logs in
    final token = LoginResponse.fromJson(json).accessToken;
    if (token.isNotEmpty) {
      await TokenStorage.saveToken(token);
    }

    if (json.containsKey('user') && json['user'] is Map<String, dynamic>) {
      return UserProfile.fromJson(json['user'] as Map<String, dynamic>);
    }
    return UserProfile.fromJson(json);
  }

  /// Logs in and saves the JWT.  Returns the authenticated user's profile.
  static Future<UserProfile> login(LoginRequest request) async {
    final data = await ApiClient.post(
      '/api/auth/login',
      body: request.toJson(),
    );
    final json = data as Map<String, dynamic>;
    final response = LoginResponse.fromJson(json);
    await TokenStorage.saveToken(response.accessToken);

    // Fetch full profile using the newly saved token
    return me();
  }

  /// Returns the current user's profile. Requires a valid saved token.
  static Future<UserProfile> me() async {
    final data = await ApiClient.get('/api/auth/me');
    return UserProfile.fromJson(data as Map<String, dynamic>);
  }

  /// Clears the saved token. The user must log in again to make authenticated requests.
  static Future<void> logout() async {
    await TokenStorage.clearToken();
  }
}
