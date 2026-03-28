import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Displays an image file, with fallback for web platform
class CrossPlatformImage extends StatelessWidget {
  final String? filePath;
  final BoxFit fit;
  final double? width;
  final double? height;

  const CrossPlatformImage({
    this.filePath,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (filePath == null || filePath!.isEmpty) {
      return _buildPlaceholder();
    }

    if (kIsWeb) {
      // On web, show placeholder since file:// URLs don't work
      return _buildPlaceholder();
    }

    // On mobile, use Image.file()
    try {
      return Image.file(
        File(filePath!),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    } catch (_) {
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(Icons.image_not_supported, color: Colors.grey),
      ),
    );
  }
}
