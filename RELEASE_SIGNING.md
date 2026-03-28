# Release Signing Setup

This guide sets up production signing for Android and iOS.

## 1) Android release signing

### Generate keystore (one-time)

Run from project root:

```powershell
keytool -genkeypair -v -keystore keys/bloomy-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias bloomy
```

### Configure signing credentials

Option A (recommended for local machine):
1. Copy `android/keystore.properties.example` to `android/keystore.properties`
2. Fill real values:

```properties
storeFile=../keys/bloomy-release.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=bloomy
keyPassword=YOUR_KEY_PASSWORD
```

Option B (CI/CD):
Set env vars:
- `ANDROID_KEYSTORE_PATH`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

### Build signed Android artifacts

```bash
flutter build appbundle --release
flutter build apk --release
```

If signing values are missing, Gradle now fails release builds with a clear error.

## 2) iOS provisioning and signing

### Apple Developer prerequisites
- Apple Developer membership active
- App ID created for bundle id: `com.bloomy.app`
- Certificates available: Apple Distribution
- Profiles created: App Store / Ad Hoc (as needed)

### Project signing config
1. Copy `ios/Flutter/Signing.xcconfig.example` to `ios/Flutter/Signing.xcconfig`
2. Set your real `DEVELOPMENT_TEAM`
3. Keep `CODE_SIGN_STYLE = Automatic` unless you intentionally use manual provisioning

### Build signed IPA (App Store)

Update team id in `ios/ExportOptions-AppStore.plist`, then run:

```bash
flutter build ipa --release --export-options-plist=ios/ExportOptions-AppStore.plist
```

### Build signed IPA (Ad Hoc)

Update team id in `ios/ExportOptions-AdHoc.plist`, then run:

```bash
flutter build ipa --release --export-options-plist=ios/ExportOptions-AdHoc.plist
```

## 3) Cloudinary config via dart-define-from-file (required for this MVP release)

If you are on Firebase Spark (free) and cannot use Secret Manager:
- Use Cloudinary **unsigned preset** mode in app defines.
- You do NOT need Firebase Functions signer for this mode.

Unsigned mode define example:

```json
{
  "EXTERNAL_IMAGE_HOST": "cloudinary",
  "CLOUDINARY_CLOUD_NAME": "your_cloud_name",
  "CLOUDINARY_UPLOAD_PRESET": "your_unsigned_preset"
}
```

Signed mode (below) needs Firebase Functions + Secret Manager (Blaze plan).

Firebase Functions secrets tip:
- Use `--data-file=-` to pipe secret values from PowerShell.
- `--value` and `--data` are not valid flags for this command.

Example:

```powershell
"dn25uwwg2" | firebase functions:secrets:set CLOUDINARY_CLOUD_NAME --data-file=- --project bloomy-d6620
```

Create a local defines file (do not commit), for example:

`config/dart_defines.local.json`

```json
{
  "EXTERNAL_IMAGE_HOST": "cloudinary",
  "CLOUDINARY_CLOUD_NAME": "your_cloud_name",
  "CLOUDINARY_API_KEY": "your_api_key",
  "CLOUDINARY_SIGN_ENDPOINT": "https://us-central1-your-project.cloudfunctions.net/cloudinarySignUpload"
}
```

Build signed Android artifact with define file:

```bash
flutter build appbundle --release --dart-define-from-file=config/dart_defines.local.json
```

Build signed iOS artifact with define file:

```bash
flutter build ipa --release --export-options-plist=ios/ExportOptions-AppStore.plist --dart-define-from-file=config/dart_defines.local.json
```

CI/CD should generate this json file from CI secrets at runtime.

GitHub Actions reference workflow is included at:
- `.github/workflows/android-release.yml`

Required GitHub secrets:
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_SIGN_ENDPOINT`

## 4) Security checklist before shipping
- Keystore and passwords are backed up securely
- `android/keystore.properties` is NOT committed
- `ios/Flutter/Signing.xcconfig` is NOT committed
- `config/dart_defines.local.json` is NOT committed
- Cloudinary API secret is only in Firebase Function secrets
- Firebase Function signer endpoint requires Firebase auth token
