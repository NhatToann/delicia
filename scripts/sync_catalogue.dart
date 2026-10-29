import 'dart:convert';
import 'dart:io';

/// Synchronizes the canonical home catalogue to Firebase without partial
/// writes. Existing products only receive the intended photo/name/category fields;
/// missing products and categories are written as complete documents.
const String databaseUrl =
    'https://delicia-60e0a-default-rtdb.asia-southeast1.firebasedatabase.app';
const String dbRoot = 'delicia';
const String catalogPath = 'scripts/catalog_reference.json';

Future<dynamic> _read(String path) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('$databaseUrl/$path.json'));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw HttpException('GET $path -> ${response.statusCode}: $body');
    }
    return body.isEmpty ? null : jsonDecode(body);
  } finally {
    client.close();
  }
}

Future<void> _write(String path, Object payload) async {
  final client = HttpClient();
  try {
    final request = await client.putUrl(Uri.parse('$databaseUrl/$path.json'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw HttpException('PUT $path -> ${response.statusCode}: $body');
    }
  } finally {
    client.close();
  }
}

Future<void> main() async {
  final catalog = jsonDecode(
    await File(catalogPath).readAsString(),
  ) as Map<String, dynamic>;
  final desiredProducts = catalog['products'] as Map<String, dynamic>;
  final desiredCategories = catalog['categories'] as Map<String, dynamic>;
  final currentProducts = await _read('$dbRoot/products');
  final currentCategories = await _read('$dbRoot/categories');
  final products = currentProducts is Map
      ? currentProducts
      : <dynamic, dynamic>{};
  final categories = currentCategories is Map
      ? currentCategories
      : <dynamic, dynamic>{};

  var addedProducts = 0;
  var updatedProducts = 0;
  var addedCategories = 0;
  for (final entry in desiredProducts.entries) {
    final existing = products[entry.key];
    final desired = Map<String, dynamic>.from(entry.value as Map);
    if (existing is! Map) {
      await _write('$dbRoot/products/${entry.key}', desired);
      addedProducts++;
      stdout.writeln('  + ${entry.key} ${desired['nameProduct']}');
      continue;
    }

    final merged = Map<String, dynamic>.from(existing);
    var changed = false;
    for (final field in <String>[
      'picture',
      'category',
      'categoryId',
      'nameProduct',
      'nameProductEn',
      'description',
    ]) {
      if (merged[field] != desired[field]) {
        merged[field] = desired[field];
        changed = true;
      }
    }
    if (changed) {
      await _write('$dbRoot/products/${entry.key}', merged);
      updatedProducts++;
      stdout.writeln('  ~ ${entry.key} photo/category updated');
    }
  }

  for (final entry in desiredCategories.entries) {
    if (categories[entry.key] != null) continue;
    await _write(
      '$dbRoot/categories/${entry.key}',
      Map<String, dynamic>.from(entry.value as Map),
    );
    addedCategories++;
    stdout.writeln('  + category ${entry.key}');
  }

  stdout.writeln(
    'Done: $addedProducts products added, $updatedProducts products updated, '
    '$addedCategories categories added.',
  );
}
