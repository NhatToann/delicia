// Shared golden-test bootstrap.
//
// `flutter_test` ships two gaps that make visual diffing useless out of the
// box:
//   * a placeholder font where every glyph is a full-width square box, and
//   * no asset bundle, so every `Image.asset` resolves to nothing.
//
// The font is fixed by loading the real TTF.  Images cannot be fixed the same
// way — `AssetImage` resolves through an asynchronous codec that the fake
// clock in `flutter_test` will never advance — so instead every bundled image
// is pre-decoded here into an [ImageProvider] that paints synchronously.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const String _fontFamily = 'LeagueSpartan';

/// Loads the app's bundled variable font so real typography is measurable.
Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final loader = FontLoader(_fontFamily);
  final file = File('assets/fonts/LeagueSpartan.ttf');
  if (file.existsSync()) {
    loader.addFont(
      Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
    );
  }
  await loader.load();
}

/// An [ImageProvider] over bytes already resident in memory.  It resolves
/// synchronously, which is exactly what the golden harness needs.
class TestMemoryImageProvider extends ImageProvider<TestMemoryImageProvider> {
  TestMemoryImageProvider(this.bytes, {this.scale = 1.0});

  final Uint8List bytes;
  final double scale;

  @override
  Future<TestMemoryImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) async => this;

  @override
  ImageStreamCompleter loadImage(
    TestMemoryImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _decode(key),
      scale: key.scale,
      debugLabel: key.bytes.length.toString(),
    );
  }

  Future<ui.Codec> _decode(TestMemoryImageProvider key) async {
    return ui.instantiateImageCodec(key.bytes);
  }

  @override
  bool operator ==(Object other) =>
      other is TestMemoryImageProvider &&
      other.bytes.length == bytes.length &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(bytes.length, scale);
}

/// Reads every file under `assets/` keyed by its bundle-relative path.
Map<String, Uint8List> readAssetTree({String root = 'assets'}) {
  final Map<String, Uint8List> data = <String, Uint8List>{};
  final dir = Directory(root);
  if (!dir.existsSync()) return data;

  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final rel = entity.path.replaceAll('\\', '/');
    final key = rel.substring(rel.indexOf('assets/'));
    data[key] = Uint8List.fromList(entity.readAsBytesSync());
  }
  return data;
}

/// Decodes every PNG/JPEG under `assets/` and registers it in the
/// [ImageCache] under the key `AssetImage` would have produced, so
/// `Image.asset` paints synchronously inside the golden harness.
Future<void> loadAppImages() async {
  final assets = readAssetTree();
  final cache = PaintingBinding.instance.imageCache;

  for (final entry in assets.entries) {
    if (!entry.key.endsWith('.png') &&
        !entry.key.endsWith('.jpg') &&
        !entry.key.endsWith('.jpeg')) {
      continue;
    }
    final codec = await ui.instantiateImageCodec(entry.value);
    final frame = await codec.getNextFrame();

    // `AssetImage.obtainKey` yields an `AssetBundleImageKey`, not an ObjectKey, so
    // the pre-decoded frame must be registered under that exact key or
    // `Image.asset` will never find it and silently falls back to its
    // `errorBuilder`.
    final assetImage = AssetImage(entry.key);
    final key = await assetImage.obtainKey(const ImageConfiguration());
    cache.putIfAbsent(
      key,
      () => OneFrameImageStreamCompleter(
        SynchronousFuture<ImageInfo>(ImageInfo(image: frame.image)),
      ),
    );
  }
}

/// Convenience: fonts + images + a working `rootBundle`.
Future<void> bootstrapGolden() async {
  await loadAppFonts();
  await loadAppImages();

  final assets = readAssetTree();
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/assets',
    (ByteData? message) async {
      if (message == null) return null;
      final key = utf8.decode(message.buffer.asUint8List());
      final bytes = assets[key];
      if (bytes == null) return null;
      return ByteData.view(bytes.buffer);
    },
  );
}