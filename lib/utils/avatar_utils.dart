import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

bool isRemoteAvatarUrl(String value) {
  return value.startsWith('http://') ||
      value.startsWith('https://') ||
      value.startsWith('gs://');
}

ImageProvider<Object>? resolveAvatarImage(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.isEmpty) {
    return null;
  }

  if (isRemoteAvatarUrl(avatarUrl)) {
    return NetworkImage(avatarUrl);
  }

  // Avoid local file access on web (throws Unsupported operation: _Namespace).
  if (kIsWeb) {
    return null;
  }

  // Ignore unknown URI schemes that are not valid local file paths.
  if (avatarUrl.contains('://')) {
    return null;
  }

  final file = File(avatarUrl);
  if (file.existsSync()) {
    return FileImage(file);
  }

  return null;
}
