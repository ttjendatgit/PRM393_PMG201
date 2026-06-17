class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.role,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? role;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? json['userId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['fullName']?.toString() ??
          json['full_name']?.toString() ??
          json['name']?.toString(),
      role: json['role']?.toString(),
    );
  }

  String get displayName => fullName?.isNotEmpty == true ? fullName! : email;
}
