class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;
  final String? firstName;
  final String? lastName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
    this.firstName,
    this.lastName,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Safely extract string values
    String getStringValue(dynamic value, [String defaultValue = '']) {
      if (value == null) return defaultValue;
      if (value is String) return value;
      return value.toString();
    }
    
    // Safely parse DateTime
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        if (value is String) {
          return DateTime.parse(value);
        } else if (value is DateTime) {
          return value;
        } else if (value is int) {
          // Handle timestamp
          return DateTime.fromMillisecondsSinceEpoch(value);
        }
      } catch (e) {
        // If parsing fails, return null
        return null;
      }
      return null;
    }
    
    // Extract ID from various possible fields
    String extractId() {
      if (json['_id'] != null) {
        return getStringValue(json['_id']);
      }
      if (json['id'] != null) {
        return getStringValue(json['id']);
      }
      return '';
    }
    
    // Extract avatar URL - handle both string and object formats
    String? extractAvatar() {
      if (json['avatar'] == null) return null;
      if (json['avatar'] is String) {
        return json['avatar'] as String;
      }
      if (json['avatar'] is Map) {
        return json['avatar']['url'] as String?;
      }
      return null;
    }
    
    return UserModel(
      id: extractId(),
      name: getStringValue(json['name']),
      email: getStringValue(json['email']),
      phone: json['phone'] != null ? getStringValue(json['phone']) : null,
      avatar: extractAvatar(),
      firstName: json['firstName'] != null ? getStringValue(json['firstName']) : null,
      lastName: json['lastName'] != null ? getStringValue(json['lastName']) : null,
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'avatar': avatar,
      'firstName': firstName,
      'lastName': lastName,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatar,
    String? firstName,
    String? lastName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
