class User {
  final String id;
  final String email;
  final String name;
  final String? deviceId;
  final DateTime? lastLogin;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.deviceId,
    this.lastLogin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      deviceId: json['device_id'],
      lastLogin: json['last_login'] != null 
          ? DateTime.parse(json['last_login']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'device_id': deviceId,
      'last_login': lastLogin?.toIso8601String(),
    };
  }
}
