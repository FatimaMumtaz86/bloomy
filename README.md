# 🌸 Bloomy — A safe space to be you

## ✨ MVP Status: **COMPLETE & FULLY FUNCTIONAL** 🎉

All core features are implemented and working, including the recently fixed image upload functionality AND new profile privacy + search features!

## 🆕 NEW FEATURES (March 26, 2026)
- ✅ **Public/Private Profile Toggle** - Control who sees your posts 🔐
- ✅ **User Discovery/Search** - Find and view other users' public profiles 🔍
- ✅ **View Public Profiles** - Browse other users' posts and info
- ✅ **Smart Feed Filtering** - Only shows posts from public profiles

## MVP Features (All Working ✅)
- ✅ Splash + Onboarding screens
- ✅ Login / Signup (local auth with persistence)
- ✅ Feed with posts (public + anonymous) — **Image uploads working!**
- ✅ Pins & Vision Boards (Pinterest-style) — **Image uploads working!**
- ✅ Mood + Period Tracker with calendar
- ✅ Journal / Diary with mood tagging
- ✅ Profile with edit + settings — **Avatar upload + privacy toggle working!**
- ✅ **Save/Bookmark posts** with persistent storage
- ✅ **Discover & search public profiles** 🔍
- ✅ **Privacy control for posts** 🔐

## Colors
- Soft Pink `#F9C5D1`
- Lavender `#C9B8E8`
- Beige `#F5ECD7`
- Cream `#FDF6EE`

## How to Use the New Features

### Profile Privacy
1. Go to **Me** (Profile tab)
2. Tap settings ⚙️ icon
3. Toggle **"Profile Privacy"** switch
4. Your profile is now PUBLIC 🌍 or PRIVATE 🔒

### Discover Other Users
1. Tap **Discover** 🔍 (bottom navigation)
2. Search for username or display name
3. Tap any user card to view their public profile
4. See their posts and profile info

### View Public Profiles
- Only public profiles appear in search
- See user info, posts, and stats
- Private profiles show lock 🔒 message

---

## How to build

### Option 1 — FlutLab.io (easiest, no setup!)
1. Go to https://flutlab.io
2. Create new project → Import zip
3. Upload `bloomy.zip`
4. Click Run or Build APK

### Option 2 — Local (Flutter installed)
```bash
cd bloomy
flutter pub get
flutter run         # for emulator
flutter build apk   # for APK
```

Release signing guide:
- See [RELEASE_SIGNING.md](RELEASE_SIGNING.md)

### Firebase rules deploy
```bash
firebase deploy --only firestore:rules --project bloomy-d6620
```

## External Image Hosting (Cloudinary)

Bloomy supports both modes:
- **Unsigned preset (FREE, no Firebase Blaze needed)**
- **Signed uploads (more secure, requires Firebase Functions + Secret Manager on Blaze plan)**

### Option A) FREE mode: Cloudinary unsigned preset

1. Open Cloudinary Console.
2. Go to **Settings > Upload > Upload presets**.
3. Create preset with **Signing Mode = Unsigned**.
4. Restrict preset:
	- Allowed formats: `jpg,jpeg,png,webp,heic,heif`
	- Max file size: `8 MB` (or lower)
	- Unique filename: ON
	- Overwrite: OFF
5. Put these values in your local define file:

```json
{
  "EXTERNAL_IMAGE_HOST": "cloudinary",
  "CLOUDINARY_CLOUD_NAME": "your_cloud_name",
  "CLOUDINARY_UPLOAD_PRESET": "your_unsigned_preset"
}
```

Run/build:

```bash
flutter run -d chrome --dart-define-from-file=config/dart_defines.local.json
flutter build apk --dart-define-from-file=config/dart_defines.local.json
```

### Option B) Signed mode (recommended for production security)

Signed mode needs Firebase Functions signer endpoint and Secret Manager, which requires **Blaze plan**.

### 1) Create Cloudinary signed upload preset
1. Open Cloudinary Console.
2. Go to **Settings > Upload > Upload presets**.
3. Create preset with **Signing Mode = Signed**.
4. Restrict preset:
	- Allowed formats: `jpg,jpeg,png,webp,heic,heif`
	- Max file size: `8 MB` (or lower)
	- Unique filename: ON
	- Use filename as public ID: OFF
5. Note these values:
	- Cloud name
	- API key
	- API secret
	- Signed upload preset

### 2) Configure and deploy signer endpoint (Firebase Functions)
Install function dependencies:

```bash
cd functions
npm install
cd ..
```

Set signer secrets (one-time):

```bash
firebase functions:secrets:set CLOUDINARY_CLOUD_NAME
firebase functions:secrets:set CLOUDINARY_API_KEY
firebase functions:secrets:set CLOUDINARY_API_SECRET
firebase functions:secrets:set CLOUDINARY_SIGNED_UPLOAD_PRESET
```

PowerShell non-interactive examples (Firebase CLI supports `--data-file`, not `--value`/`--data`):

```powershell
"dn25uwwg2" | firebase functions:secrets:set CLOUDINARY_CLOUD_NAME --data-file=- --project bloomy-d6620
"your_api_key" | firebase functions:secrets:set CLOUDINARY_API_KEY --data-file=- --project bloomy-d6620
"your_api_secret" | firebase functions:secrets:set CLOUDINARY_API_SECRET --data-file=- --project bloomy-d6620
"bloomy_signed_upload" | firebase functions:secrets:set CLOUDINARY_SIGNED_UPLOAD_PRESET --data-file=- --project bloomy-d6620
```

Deploy functions:

```bash
firebase deploy --only functions --project bloomy-d6620
```

After deploy, copy signer URL from Firebase output. Example:
`https://us-central1-bloomy-d6620.cloudfunctions.net/cloudinarySignUpload`

### 3) Run/Build app with signed upload env
Use `--dart-define-from-file` for local and CI builds.

Create a local file (example): `config/dart_defines.local.json`

```json
{
  "EXTERNAL_IMAGE_HOST": "cloudinary",
  "CLOUDINARY_CLOUD_NAME": "your_cloud_name",
  "CLOUDINARY_API_KEY": "your_api_key",
  "CLOUDINARY_SIGN_ENDPOINT": "https://us-central1-your-project.cloudfunctions.net/cloudinarySignUpload"
}
```

Then run build with that file:

```bash
flutter build apk --dart-define-from-file=config/dart_defines.local.json
```

### 4) What this enables
- Upload for profile avatars
- Upload for post images
- Upload for pin images

Yes, before build you should provide Cloudinary values through the dart-define file.

## iOS Universal Links checklist
- Associated domains are configured in [ios/Runner/Runner.entitlements](ios/Runner/Runner.entitlements).
- Ensure both domains in that file are real domains you own.
- Host `apple-app-site-association` at:
	- `https://bloomy.app/.well-known/apple-app-site-association`
	- `https://www.bloomy.app/.well-known/apple-app-site-association`
- Rebuild the iOS app after entitlements/domain changes.

## APK location after build
`build/app/outputs/flutter-apk/app-release.apk`

## Web + APK Distribution (Vercel + Play Console)

### Privacy policy URL (for Play Console)
After deployment, use this URL in Play Console:

`https://<your-domain>/privacy-policy.html`

This page is included in web source and release output:
- `web/privacy-policy.html`
- `build/web/privacy-policy.html`

### Web deployment on Vercel
You can deploy either from source or prebuilt static files.

Option A: Deploy prebuilt static folder
1. Build web locally:
	`flutter build web --release --dart-define-from-file=config/dart_defines.local.json`
2. Upload `build/web` to Vercel as static output (or commit it in `web_release/`).

Option B: Let Vercel build from source
1. Build command: `flutter build web --release --dart-define-from-file=config/dart_defines.local.json`
2. Output directory: `build/web`

### APK download trust info
Current release metadata:
- Version: `1.0.0+1`
- SHA1: `9fe2478497cafe44d968af7992554002e58b440a`

Add these near your APK download link on website so users can verify integrity.

### Recommended APK hosting
Best simple option: upload APK to GitHub Releases and use:

`https://github.com/FatimaMumtaz86/bloomy/releases/latest/download/app-release.apk`

The web `Download Android APK` button is already configured to this URL in `web/index.html`.

## Implementation Details

### Image Upload
- Uses `image_picker` package for gallery access
- Images stored locally as file paths
- Full preview before posting/pinning
- Error handling for missing/corrupted images

### Save/Bookmark System
- New `SavedPostProvider` for state management
- Persistent storage via SharedPreferences
- Visual feedback (filled/outlined bookmark icon)
- Synchronized across app sessions

### Profile Privacy & Search
- New `UserProvider` manages user directory
- Public/private setting stored in UserModel
- Smart feed filtering hides private users' posts
- Search only shows public profiles
- Demo users included for testing

## All Features Working:
- ✅ Authentication & persistence
- ✅ Create posts with images & tags
- ✅ Like posts (per user)
- ✅ Save/bookmark posts
- ✅ Log moods with calendar
- ✅ Track period & pain levels
- ✅ Write journal entries
- ✅ Edit profile & upload avatar
- ✅ **Toggle profile privacy** (NEW!)
- ✅ **Search & discover users** (NEW!)
- ✅ **View public profiles** (NEW!)
- ✅ Settings menu
- ✅ Anonymous posting option

---

**Ready for testing and use!** 🌸
