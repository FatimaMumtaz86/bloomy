import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ExternalImageHostService {
  static const String _hostProvider = String.fromEnvironment(
    'EXTERNAL_IMAGE_HOST',
    defaultValue: '',
  );
  static const String _cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '',
  );
  static const String _cloudinaryApiKey = String.fromEnvironment(
    'CLOUDINARY_API_KEY',
    defaultValue: '',
  );
  static const String _cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: '',
  );
  static const String _cloudinarySignEndpoint = String.fromEnvironment(
    'CLOUDINARY_SIGN_ENDPOINT',
    defaultValue: '',
  );

  static const int _maxImageSizeBytes = 8 * 1024 * 1024;
  static const Set<String> _allowedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
  };

  bool _isRealDefineValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    // Guard against template placeholders accidentally copied into runtime defines.
    if (normalized.contains('your_') ||
        normalized.contains('your-project') ||
        normalized.contains('optional') ||
        normalized.contains('example')) {
      return false;
    }

    return true;
  }

  bool get _isSignedConfigured {
    return _isRealDefineValue(_cloudinaryCloudName) &&
        _isRealDefineValue(_cloudinaryApiKey) &&
        _isRealDefineValue(_cloudinarySignEndpoint);
  }

  bool get _isUnsignedConfigured {
    return _isRealDefineValue(_cloudinaryCloudName) &&
        _isRealDefineValue(_cloudinaryUploadPreset);
  }

  bool get isConfigured {
    return _hostProvider.toLowerCase() == 'cloudinary' &&
        (_isSignedConfigured || _isUnsignedConfigured);
  }

  Future<String?> uploadImageFromFilePath({
    required String filePath,
    required String folder,
    required String userId,
    required String objectId,
  }) async {
    if (!isConfigured) {
      return null;
    }

    if (kIsWeb) {
      throw Exception(
        'External host upload from local web paths is not supported. Use a mobile device for uploads or provide a remote URL.',
      );
    }

    switch (_hostProvider.toLowerCase()) {
      case 'cloudinary':
        if (_isSignedConfigured) {
          return _uploadToCloudinarySigned(
            filePath: filePath,
            folder: folder,
            userId: userId,
            objectId: objectId,
          );
        }

        if (_isUnsignedConfigured) {
          return _uploadToCloudinaryUnsigned(
            filePath: filePath,
            folder: folder,
            userId: userId,
            objectId: objectId,
          );
        }

        return null;
      default:
        return null;
    }
  }

  Future<String?> uploadImageFromBytes({
    required Uint8List bytes,
    required String fileName,
    required String folder,
    required String userId,
    required String objectId,
  }) async {
    if (!isConfigured) {
      return null;
    }

    switch (_hostProvider.toLowerCase()) {
      case 'cloudinary':
        if (_isSignedConfigured) {
          return _uploadToCloudinarySignedFromBytes(
            bytes: bytes,
            fileName: fileName,
            folder: folder,
            userId: userId,
            objectId: objectId,
          );
        }

        if (_isUnsignedConfigured) {
          return _uploadToCloudinaryUnsignedFromBytes(
            bytes: bytes,
            fileName: fileName,
            folder: folder,
            userId: userId,
            objectId: objectId,
          );
        }

        return null;
      default:
        return null;
    }
  }

  Future<String> _uploadToCloudinarySigned({
    required String filePath,
    required String folder,
    required String userId,
    required String objectId,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Image file not found at path: $filePath');
    }

    _validateUploadFile(file);

    final signedPayload = await _fetchSignedPayload(
      folder: folder,
      objectId: objectId,
    );

    final endpoint = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
    );

    final request = _buildSignedUploadRequest(
      endpoint: endpoint,
      signedPayload: signedPayload,
    )..files.add(await http.MultipartFile.fromPath('file', file.path));

    return _sendUploadRequest(request);
  }

  Future<String> _uploadToCloudinarySignedFromBytes({
    required Uint8List bytes,
    required String fileName,
    required String folder,
    required String userId,
    required String objectId,
  }) async {
    _validateUploadBytes(bytes, fileName: fileName);

    final signedPayload = await _fetchSignedPayload(
      folder: folder,
      objectId: objectId,
    );

    final endpoint = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
    );

    final request = _buildSignedUploadRequest(
      endpoint: endpoint,
      signedPayload: signedPayload,
    )
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

    return _sendUploadRequest(request);
  }

  Future<String> _uploadToCloudinaryUnsigned({
    required String filePath,
    required String folder,
    required String userId,
    required String objectId,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Image file not found at path: $filePath');
    }

    _validateUploadFile(file);

    final endpoint = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
    );

    final request = _buildUnsignedUploadRequest(
      endpoint: endpoint,
      folder: folder,
      userId: userId,
    )..files.add(await http.MultipartFile.fromPath('file', file.path));

    return _sendUploadRequest(request);
  }

  Future<String> _uploadToCloudinaryUnsignedFromBytes({
    required Uint8List bytes,
    required String fileName,
    required String folder,
    required String userId,
    required String objectId,
  }) async {
    _validateUploadBytes(bytes, fileName: fileName);

    final endpoint = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
    );

    final request = _buildUnsignedUploadRequest(
      endpoint: endpoint,
      folder: folder,
      userId: userId,
    )
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

    return _sendUploadRequest(request);
  }

  http.MultipartRequest _buildSignedUploadRequest({
    required Uri endpoint,
    required Map<String, String> signedPayload,
  }) {
    return http.MultipartRequest('POST', endpoint)
      ..fields['api_key'] = _cloudinaryApiKey
      ..fields['timestamp'] = signedPayload['timestamp']!
      ..fields['signature'] = signedPayload['signature']!
      ..fields['folder'] = signedPayload['folder']!
      ..fields['public_id'] = signedPayload['public_id']!
      ..fields['overwrite'] = signedPayload['overwrite']!
      ..fields['upload_preset'] = signedPayload['upload_preset']!
      ..fields['tags'] = signedPayload['tags']!
      ..fields['context'] = signedPayload['context']!;
  }

  http.MultipartRequest _buildUnsignedUploadRequest({
    required Uri endpoint,
    required String folder,
    required String userId,
  }) {
    return http.MultipartRequest('POST', endpoint)
      ..fields['upload_preset'] = _cloudinaryUploadPreset
      ..fields['folder'] = 'bloomy/$folder/$userId';
  }

  Future<String> _sendUploadRequest(http.MultipartRequest request) async {
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    Map<String, dynamic> payload = <String, dynamic>{};
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        payload = decoded;
      }
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final dynamic errorRaw = payload['error'];
      final String errorMessage;
      if (errorRaw is Map<String, dynamic>) {
        errorMessage =
            (errorRaw['message'] ?? 'Unknown Cloudinary error').toString();
      } else {
        errorMessage = (errorRaw ?? responseBody).toString();
      }
      throw Exception(
        'Cloudinary upload failed (${response.statusCode}): $errorMessage',
      );
    }

    final secureUrl = (payload['secure_url'] ?? payload['url'])?.toString();
    if (secureUrl == null || secureUrl.isEmpty) {
      throw Exception('Cloudinary upload did not return a valid image URL.');
    }

    return secureUrl;
  }

  Future<Map<String, String>> _fetchSignedPayload({
    required String folder,
    required String objectId,
  }) async {
    final endpoint = Uri.parse(_cloudinarySignEndpoint);
    final currentUser = FirebaseAuth.instance.currentUser;

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (currentUser != null) {
      final token = await currentUser.getIdToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final response = await http.post(
      endpoint,
      headers: headers,
      body: jsonEncode({
        'folder': folder,
        'objectId': objectId,
      }),
    );

    Map<String, dynamic> payload = <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        payload = decoded;
      }
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          (payload['error'] ?? payload['message'] ?? response.body).toString();
      throw Exception(
        'Cloudinary signer failed (${response.statusCode}): $message',
      );
    }

    final cloudName = (payload['cloud_name'] ?? '').toString();
    if (cloudName.isNotEmpty && cloudName != _cloudinaryCloudName) {
      throw Exception(
        'Signer cloud mismatch. Expected $_cloudinaryCloudName but got $cloudName.',
      );
    }

    final signed = <String, String>{
      'timestamp': (payload['timestamp'] ?? '').toString(),
      'signature': (payload['signature'] ?? '').toString(),
      'folder': (payload['folder'] ?? '').toString(),
      'public_id': (payload['public_id'] ?? '').toString(),
      'overwrite': (payload['overwrite'] ?? '').toString(),
      'upload_preset': (payload['upload_preset'] ?? '').toString(),
      'tags': (payload['tags'] ?? '').toString(),
      'context': (payload['context'] ?? '').toString(),
    };

    final missing = signed.entries
        .where((entry) => entry.value.isEmpty)
        .map((entry) => entry.key)
        .toList();

    if (missing.isNotEmpty) {
      throw Exception(
        'Signer returned incomplete payload. Missing: ${missing.join(', ')}',
      );
    }

    return signed;
  }

  void _validateUploadFile(File file) {
    final fileLength = file.lengthSync();
    if (fileLength <= 0) {
      throw Exception('Selected image is empty.');
    }

    if (fileLength > _maxImageSizeBytes) {
      throw Exception(
        'Image is too large. Please upload a file under 8 MB.',
      );
    }

    final path = file.path.toLowerCase();
    final dotIndex = path.lastIndexOf('.');
    final ext = dotIndex == -1 ? '' : path.substring(dotIndex + 1);
    if (!_allowedExtensions.contains(ext)) {
      throw Exception(
        'Unsupported image format. Allowed: jpg, jpeg, png, webp, heic, heif.',
      );
    }
  }

  void _validateUploadBytes(
    Uint8List bytes, {
    required String fileName,
  }) {
    if (bytes.isEmpty) {
      throw Exception('Selected image is empty.');
    }

    if (bytes.length > _maxImageSizeBytes) {
      throw Exception(
        'Image is too large. Please upload a file under 8 MB.',
      );
    }

    final normalizedName = fileName.toLowerCase();
    final dotIndex = normalizedName.lastIndexOf('.');
    final ext = dotIndex == -1 ? '' : normalizedName.substring(dotIndex + 1);
    if (!_allowedExtensions.contains(ext)) {
      throw Exception(
        'Unsupported image format. Allowed: jpg, jpeg, png, webp, heic, heif.',
      );
    }
  }
}
