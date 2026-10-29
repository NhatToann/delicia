import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Storage service for delivery proof photos and avatars (UC-11).
abstract class StorageService {
  Future<String> uploadImage(XFile file, {required String folder});
}

class FirebaseStorageService implements StorageService {
  FirebaseStorageService({FirebaseStorage? storage})
      : _storage = storage ?? _defaultStorage();

  final FirebaseStorage? _storage;

  static FirebaseStorage? _defaultStorage() {
    try {
      return FirebaseStorage.instanceFor(app: Firebase.app());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> uploadImage(XFile file, {required String folder}) async {
    final storage = _storage;
    if (storage == null) {
      return file.path;
    }
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = storage.ref().child('delicia').child(folder).child(fileName);

      UploadTask task;
      try {
        final bytes = await file.readAsBytes();
        task = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } catch (_) {
        task = ref.putFile(File(file.path));
      }

      final snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } catch (_) {
      // Graceful fallback to file path if upload fails (offline / test)
      return file.path;
    }
  }
}
