/// A delivery driver account (UC-09).
///
/// Delivery users live in the same `users/{uid}` node as every other
/// account — they are told apart by `rolId == 3`. The admin screens
/// (list / enable / disable) need a couple of extra fields on top of
/// the profile, so this model carries them.
class DeliveryUser {
  /// Firebase uid of the account.
  final String uid;

  /// Display name — the full name of the driver.
  final String name;

  /// Contact phone number, when the account has one.
  final String phone;

  /// Contact email address.
  final String email;

  /// Whether the account may receive orders.
  ///
  /// A disabled driver stays in the database (their history is kept) but
  /// is hidden from the "assign a driver" list.
  final bool isEnabled;

  /// How many orders are currently assigned to this driver.
  final int activeOrders;

  const DeliveryUser({
    required this.uid,
    required this.name,
    this.phone = '',
    this.email = '',
    this.isEnabled = true,
    this.activeOrders = 0,
  });

  /// The initial value of the delivery list state.
  static const DeliveryUser empty = DeliveryUser(uid: '', name: '');

  DeliveryUser copyWith({
    String? uid,
    String? name,
    String? phone,
    String? email,
    bool? isEnabled,
    int? activeOrders,
  }) =>
      DeliveryUser(
        uid: uid ?? this.uid,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        isEnabled: isEnabled ?? this.isEnabled,
        activeOrders: activeOrders ?? this.activeOrders,
      );

  /// Builds a driver from a raw `users/{uid}` payload.
  ///
  /// A missing `enabled` flag means "enabled" — every account created
  /// before the admin console existed must keep working.
  factory DeliveryUser.fromMap(String uid, Map<dynamic, dynamic> map) {
    final first = (map['firstName'] ?? '').toString().trim();
    final last = (map['lastName'] ?? '').toString().trim();
    final full = '$first $last'.trim();
    return DeliveryUser(
      uid: uid,
      name: full.isNotEmpty ? full : (map['email'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      isEnabled: _parseBool(map['enabled'], fallback: true),
      activeOrders: int.tryParse((map['activeOrders'] ?? '0').toString()) ?? 0,
    );
  }

  static bool _parseBool(dynamic raw, {required bool fallback}) {
    if (raw == null) return fallback;
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final value = raw.toString().toLowerCase();
    if (value == 'true' || value == '1') return true;
    if (value == 'false' || value == '0') return false;
    return fallback;
  }
}
