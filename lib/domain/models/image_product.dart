/// Auxiliary image for a product (UC-02).
///
/// Stored under `/delicia/products/{productId}/images/{id}` so a single
/// product can have a carousel of pictures.
class ImageProductdb {
  final String id;
  final String picture;
  final String productId;

  const ImageProductdb({
    required this.id,
    required this.picture,
    required this.productId,
  });

  factory ImageProductdb.fromMap(
    String productId,
    String id,
    Map<dynamic, dynamic> map,
  ) {
    return ImageProductdb(
      id: id,
      productId: productId,
      picture: (map['picture'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'picture': picture,
        'productId': productId,
      };
}