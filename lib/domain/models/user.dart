/// Minimal User model used by the Auth flow.
///
/// Only fields actually consumed in UC-01 are kept. The full model is added in
/// UC-06 (profile/address management).
class User {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String? image;
  final String? phone;
  final String? dateOfBirth;
  final int rolId; // 1=Admin, 2=Client, 3=Delivery

  const User({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.image,
    this.phone,
    this.dateOfBirth,
    required this.rolId,
  });

  String get fullName => '$firstName $lastName'.trim();

  User copyWith({
    String? firstName,
    String? lastName,
    String? image,
    String? phone,
    String? dateOfBirth,
  }) => User(
    uid: uid,
    email: email,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    image: image ?? this.image,
    phone: phone ?? this.phone,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    rolId: rolId,
  );

  factory User.fromMap(Map<dynamic, dynamic> map) {
    return User(
      uid: (map['uid'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      firstName: (map['firstName'] ?? '') as String,
      lastName: (map['lastName'] ?? '') as String,
      image: map['image'] as String?,
      phone: map['phone'] as String?,
      dateOfBirth: map['dateOfBirth'] as String?,
      rolId: int.tryParse((map['rolId'] ?? '2').toString()) ?? 2,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'image': image,
        'phone': phone,
        'dateOfBirth': dateOfBirth,
        'rolId': rolId,
      };
}
