class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    this.createdAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: _readString(json['id']),
      email: _readString(json['email']),
      role: _readString(json['role']),
      createdAt: DateTime.tryParse(_readString(json['createdAt'])),
    );
  }

  final String id;
  final String email;
  final String role;
  final DateTime? createdAt;

  static String _readString(Object? value) {
    return value is String ? value : '';
  }
}
