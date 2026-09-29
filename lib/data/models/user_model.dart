enum SubscriptionPlan { free, premiumMonthly, premiumYearly, lifetime }

class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;
  final SubscriptionPlan plan;
  final DateTime? planExpiresAt;

  const UserModel({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.emailVerified = false,
    this.plan = SubscriptionPlan.free,
    this.planExpiresAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String?,
        photoUrl: json['photo_url'] as String?,
        emailVerified: json['email_verified'] as bool? ?? false,
        plan: SubscriptionPlan.values.firstWhere(
          (p) => p.name == json['plan'],
          orElse: () => SubscriptionPlan.free,
        ),
        planExpiresAt: json['plan_expires_at'] != null
            ? DateTime.tryParse(json['plan_expires_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'photo_url': photoUrl,
        'email_verified': emailVerified,
        'plan': plan.name,
        'plan_expires_at': planExpiresAt?.toIso8601String(),
      };

  UserModel copyWith({
    String? displayName,
    String? photoUrl,
    bool? emailVerified,
    SubscriptionPlan? plan,
    DateTime? planExpiresAt,
  }) {
    return UserModel(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      emailVerified: emailVerified ?? this.emailVerified,
      plan: plan ?? this.plan,
      planExpiresAt: planExpiresAt ?? this.planExpiresAt,
    );
  }
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  const AuthTokens({required this.accessToken, required this.refreshToken});
}
