class UserProfile {
  final String id;
  final String name;
  final String email;
  final int age;
  final String ageGroup;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.age,
    required this.ageGroup,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        age: json['age'] ?? 0,
        ageGroup: json['age_group'] ?? 'Adult',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'age': age,
        'age_group': ageGroup,
      };
}
