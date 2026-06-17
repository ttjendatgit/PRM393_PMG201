class LoginResponse {
  const LoginResponse({required this.accessToken});

  final String accessToken;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    // Support multiple key names used by different ASP.NET configurations
    final token = json['accessToken'] as String? ??
        json['access_token'] as String? ??
        json['token'] as String? ??
        json['jwt'] as String? ??
        '';
    return LoginResponse(accessToken: token);
  }
}
