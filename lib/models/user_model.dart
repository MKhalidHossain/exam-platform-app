class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;
  final String? firstName;
  final String? lastName;
  final bool? notifications;
  final String? language;
  final String? country;
  final String? status;
  final String? role;
  final int? fine;
  final String? referralCode;
  final String? subscriptionTier;
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
    this.notifications,
    this.language,
    this.country,
    this.status,
    this.role,
    this.fine,
    this.referralCode,
    this.subscriptionTier,
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

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
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
      notifications: json['notifications'] is bool ? json['notifications'] as bool : null,
      language: json['language'] != null ? getStringValue(json['language']) : null,
      country: json['country'] != null ? getStringValue(json['country']) : null,
      status: json['status'] != null ? getStringValue(json['status']) : null,
      role: json['role'] != null ? getStringValue(json['role']) : null,
      fine: parseInt(json['fine']),
      referralCode:
          json['referralCode'] != null ? getStringValue(json['referralCode']) : null,
      subscriptionTier: json['subscriptionTier'] != null
          ? getStringValue(json['subscriptionTier'])
          : null,
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
      'notifications': notifications,
      'language': language,
      'country': country,
      'status': status,
      'role': role,
      'fine': fine,
      'referralCode': referralCode,
      'subscriptionTier': subscriptionTier,
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
    bool? notifications,
    String? language,
    String? country,
    String? status,
    String? role,
    int? fine,
    String? referralCode,
    String? subscriptionTier,
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
      notifications: notifications ?? this.notifications,
      language: language ?? this.language,
      country: country ?? this.country,
      status: status ?? this.status,
      role: role ?? this.role,
      fine: fine ?? this.fine,
      referralCode: referralCode ?? this.referralCode,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
