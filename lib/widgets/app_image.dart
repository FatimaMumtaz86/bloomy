import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

/// Smart image widget that handles both network and local images with caching
class AppImage extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final VoidCallback? onImageLoaded;

  const AppImage({
    this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.onImageLoaded,
    super.key,
  });

  bool _isNetworkImage(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || 
           url.startsWith('https://') || 
           url.startsWith('gs://');
  }

  Widget _buildPlaceholder() {
    return placeholder ?? Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined, color: Colors.grey),
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    // Network image
    if (_isNetworkImage(imageUrl)) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: fit,
        width: width,
        height: height,
        placeholder: (_, __) => _buildShimmer(),
        errorWidget: (_, __, ___) => _buildPlaceholder(),
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 300),
      );
    }

    // Local file image
    if (kIsWeb) {
      return _buildPlaceholder();
    }

    try {
      return Image.file(
        File(imageUrl!),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    } catch (_) {
      return _buildPlaceholder();
    }
  }
}

/// Image widget that caches remote intrinsic aspect ratio per URL and
/// renders media using an adaptive frame.
class AdaptiveAspectImage extends StatefulWidget {
  final String? imageUrl;
  final double fallbackAspectRatio;
  final double minAspectRatio;
  final double maxAspectRatio;
  final BoxFit fit;
  final Color backgroundColor;
  final Widget? placeholder;

  const AdaptiveAspectImage({
    super.key,
    required this.imageUrl,
    required this.fallbackAspectRatio,
    required this.fit,
    this.minAspectRatio = 0.55,
    this.maxAspectRatio = 1.9,
    this.backgroundColor = Colors.transparent,
    this.placeholder,
  });

  @override
  State<AdaptiveAspectImage> createState() => _AdaptiveAspectImageState();
}

class _AdaptiveAspectImageState extends State<AdaptiveAspectImage> {
  static final Map<String, double> _ratioCache = <String, double>{};

  ImageStream? _stream;
  ImageStreamListener? _listener;
  double? _resolvedAspectRatio;

  @override
  void initState() {
    super.initState();
    _primeAspectRatio();
  }

  @override
  void didUpdateWidget(covariant AdaptiveAspectImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _removeImageListener();
      _resolvedAspectRatio = null;
      _primeAspectRatio();
    }
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  bool _isNetworkImage(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    return url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('gs://');
  }

  void _primeAspectRatio() {
    final url = widget.imageUrl;
    if (!_isNetworkImage(url)) {
      return;
    }

    final cached = _ratioCache[url!];
    if (cached != null) {
      _resolvedAspectRatio = cached;
      return;
    }

    final provider = CachedNetworkImageProvider(url);
    _stream = provider.resolve(const ImageConfiguration());
    _listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final width = info.image.width.toDouble();
        final height = info.image.height.toDouble();
        if (width <= 0 || height <= 0) {
          _removeImageListener();
          return;
        }

        final ratio = (width / height)
            .clamp(widget.minAspectRatio, widget.maxAspectRatio)
            .toDouble();
        _ratioCache[url] = ratio;
        if (mounted) {
          setState(() {
            _resolvedAspectRatio = ratio;
          });
        }
        _removeImageListener();
      },
      onError: (_, __) {
        _removeImageListener();
      },
    );
    _stream?.addListener(_listener!);
  }

  void _removeImageListener() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  @override
  Widget build(BuildContext context) {
    final ratio =
        (_resolvedAspectRatio ?? widget.fallbackAspectRatio)
            .clamp(widget.minAspectRatio, widget.maxAspectRatio)
            .toDouble();

    return Container(
      color: widget.backgroundColor,
      child: AspectRatio(
        aspectRatio: ratio,
        child: AppImage(
          imageUrl: widget.imageUrl,
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
          placeholder: widget.placeholder,
        ),
      ),
    );
  }
}
