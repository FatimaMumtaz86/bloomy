import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

class ScreenshotSecurityService {
  static Future<void> setProtectionEnabled(bool enabled) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }

    if (enabled) {
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
    } else {
      await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    }
  }
}
