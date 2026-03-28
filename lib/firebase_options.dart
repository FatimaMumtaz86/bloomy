import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'bloomy-d6620',
  );
  static const _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '410774589175',
  );
  static const _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'bloomy-d6620.firebasestorage.app',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return ios;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_ANDROID_API_KEY',
      defaultValue: 'AIzaSyDW0srH4LU_37NMGCAl8hqC6hXCXWurb2Y',
    ),
    appId: String.fromEnvironment(
      'FIREBASE_ANDROID_APP_ID',
      defaultValue: '1:410774589175:android:411704279c00c99a664df2',
    ),
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
  );

  static FirebaseOptions get ios {
    const apiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
    const bundleId = String.fromEnvironment(
      'FIREBASE_IOS_BUNDLE_ID',
      defaultValue: 'com.bloomy.app',
    );
    _validateRequired('FIREBASE_IOS_API_KEY', apiKey);
    _validateRequired('FIREBASE_IOS_APP_ID', appId);
    _validateRequired('FIREBASE_IOS_BUNDLE_ID', bundleId);
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      iosBundleId: bundleId,
      storageBucket: _storageBucket,
    );
  }

  static FirebaseOptions get web {
    const apiKey = String.fromEnvironment(
      'FIREBASE_WEB_API_KEY',
      defaultValue: 'AIzaSyAlCEXsMlvig-arerx9TSabrCGgFkuma6w',
    );
    const appId = String.fromEnvironment(
      'FIREBASE_WEB_APP_ID',
      defaultValue: '1:410774589175:web:a2bd73739ffad4de664df2',
    );
    const authDomain = String.fromEnvironment(
      'FIREBASE_WEB_AUTH_DOMAIN',
      defaultValue: 'bloomy-d6620.firebaseapp.com',
    );
    const measurementId = String.fromEnvironment(
      'FIREBASE_WEB_MEASUREMENT_ID',
      defaultValue: 'G-8W22W78NS5',
    );
    _validateRequired('FIREBASE_WEB_API_KEY', apiKey);
    _validateRequired('FIREBASE_WEB_APP_ID', appId);
    _validateRequired('FIREBASE_WEB_AUTH_DOMAIN', authDomain);
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      authDomain: authDomain,
      storageBucket: _storageBucket,
      measurementId: measurementId.isEmpty ? null : measurementId,
    );
  }

  static void _validateRequired(String key, String value) {
    if (value.isEmpty || value.toLowerCase().contains('placeholder')) {
      throw StateError(
        'Missing Firebase config for $key. Pass it via --dart-define during build/run.',
      );
    }
  }
}
