/// A customer account (UC-07).
///
/// The dashboard shows how many *new* customers registered today, which
/// means the account needs the moment it was created — the plain `User`
/// profile model does not carry it.
class CustomerAccount {
  /// Firebase uid of the account.
  final String uid;

  /// Display name — the full name of the customer.
  final String name;

  /// Contact email address.
  final String email;

  /// When the account was registered.
  ///
  /// Accounts created before the timestamp existed fall back to the
  /// epoch — they are never counted as "new".
  final DateTime createdAt;

  const CustomerAccount({
    required this.uid,
    required this.name,
    this.email = '',
    required this.createdAt,
  });

  /// Builds a customer from a raw `users/{uid}` payload.
  factory CustomerAccount.fromMap(String uid, Map<dynamic, dynamic> map) {
    final first = (map['firstName'] ?? '').toString().trim();
    final last = (map['lastName'] ?? '').toString().trim();
    final full = '$first $last'.trim();
    return CustomerAccount(
      uid: uid,
      name: full.isNotEmpty ? full : (map['email'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse((map['createdAt'] ?? 0).toString()) ?? 0,
      ),
    );
  }
}
