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
  final int rolId; // 1=Client, 2=Admin, 3=Delivery

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

  /// Factory constructor to create a User from a Map (e.g., Firebase snapshot).
  /// Hỗ trợ cả 2 cách gọi:
  /// 1. User.fromMap(map) -> tự lấy uid bên trong map
  /// 2. User.fromMap(map, uid) -> truyền trực tiếp uid ở tham số thứ 2
  factory User.fromMap(Map<dynamic, dynamic> map, [String? explicitUid]) {
    return User(
      uid: explicitUid ?? map['uid']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      firstName: map['firstName']?.toString() ?? '',
      lastName: map['lastName']?.toString() ?? '',
      phone: map['phone']?.toString(),
      image: map['image']?.toString(),
      rolId: map['rolId'] is int
          ? map['rolId']
          : int.tryParse(map['rolId']?.toString() ?? '2') ?? 2,
      dateOfBirth: map['dateOfBirth']?.toString(), // Đọc ngày sinh từ Firebase
    );
  }

  String get fullName => '$firstName $lastName'.trim();

  User copyWith({
    String? firstName,
    String? lastName,
    String? image,
    String? phone,
    String? dateOfBirth,
    int? rolId,
  }) => User(
    uid: uid,
    email: email,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    image: image ?? this.image,
    phone: phone ?? this.phone,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    rolId: rolId ?? this.rolId,
  );

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