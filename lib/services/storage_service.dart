import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload post image
  Future<String?> uploadPostImage({
    required String userId,
    required String postId,
    required XFile imageFile,
  }) async {
    try {
      final ref = _storage
          .ref()
          .child('posts')
          .child(userId)
          .child('$postId.jpg');

      final file = File(imageFile.path);
      final uploadTask = ref.putFile(file);

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload post image: $e');
    }
  }

  /// Upload pin image
  Future<String?> uploadPinImage({
    required String userId,
    required String pinId,
    required XFile imageFile,
  }) async {
    try {
      final ref = _storage
          .ref()
          .child('pins')
          .child(userId)
          .child('$pinId.jpg');

      final file = File(imageFile.path);
      final uploadTask = ref.putFile(file);

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload pin image: $e');
    }
  }

  /// Upload avatar image
  Future<String?> uploadAvatarImage({
    required String userId,
    required XFile imageFile,
  }) async {
    try {
      final ref = _storage
          .ref()
          .child('avatars')
          .child('$userId.jpg');

      final file = File(imageFile.path);
      final uploadTask = ref.putFile(file);

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload avatar image: $e');
    }
  }

  /// Upload board cover image
  Future<String?> uploadBoardCoverImage({
    required String userId,
    required String boardId,
    required XFile imageFile,
  }) async {
    try {
      final ref = _storage
          .ref()
          .child('boards')
          .child(userId)
          .child('$boardId.jpg');

      final file = File(imageFile.path);
      final uploadTask = ref.putFile(file);

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload board cover image: $e');
    }
  }

  /// Delete a file from storage
  Future<void> deleteFile(String filePath) async {
    try {
      final ref = _storage.ref().child(filePath);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  /// Get download URL for a file
  Future<String?> getDownloadUrl(String filePath) async {
    try {
      final ref = _storage.ref().child(filePath);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to get download URL: $e');
    }
  }
}
