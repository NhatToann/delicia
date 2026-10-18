/// Product model (UC-02).
///
/// Stored under `/delicia/products/{id}` in the Realtime Database.
/// The `status` field mirrors the original Frave backend: `1` = active,
/// `0` = sold out / inactive.
class Productsdb {
  final String id;
  final String nameProduct;
  final String description;
  final double price;
  final int status;
  final String picture;
  final String category;
  final String categoryId;

  const Productsdb({
    required this.id,
    required this.nameProduct,
    required this.description,
    required this.price,
    required this.status,
    required this.picture,
    required this.category,
    required this.categoryId,
  });

  factory Productsdb.fromMap(String id, Map<dynamic, dynamic> map) {
    return Productsdb(
      id: id,
      nameProduct: (map['nameProduct'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      price: _parseDouble(map['price']),
      status: int.tryParse((map['status'] ?? '1').toString()) ?? 1,
      picture: (map['picture'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      categoryId: (map['categoryId'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'nameProduct': nameProduct,
        'description': description,
        'price': price,
        'status': status,
        'picture': picture,
        'category': category,
        'categoryId': categoryId,
      };

  bool get isActive => status == 1;

  Productsdb copyWith({
    String? id,
    String? nameProduct,
    String? description,
    double? price,
    int? status,
    String? picture,
    String? category,
    String? categoryId,
  }) =>
      Productsdb(
        id: id ?? this.id,
        nameProduct: nameProduct ?? this.nameProduct,
        description: description ?? this.description,
        price: price ?? this.price,
        status: status ?? this.status,
        picture: picture ?? this.picture,
        category: category ?? this.category,
        categoryId: categoryId ?? this.categoryId,
      );

  static double _parseDouble(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0.0;
  }
}