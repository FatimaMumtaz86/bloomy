import 'dart:async';

import 'package:app_links/app_links.dart';

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  Future<void> initialize({
    required void Function(Uri uri) onUri,
  }) async {
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      onUri(initialUri);
    }

    _subscription ??= _appLinks.uriLinkStream.listen(onUri);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
