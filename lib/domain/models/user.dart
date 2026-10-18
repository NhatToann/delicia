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
  final int rolId; // 1=Admin, 2=Client, 3=Delivery

  const User({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.image,
    this.phone,
    required this.rolId,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory User.fromMap(Map<dynamic, dynamic> map) {
    return User(
      uid: (map['uid'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      firstName: (map['firstName'] ?? '') as String,
      lastName: (map['lastName'] ?? '') as String,
      image: map['image'] as String?,
      phone: map['phone'] as String?,
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
        'rolId': rolId,
      };
}
