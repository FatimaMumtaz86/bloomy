Use a single square PNG logo for all app icons and splash screens.

Required file:
- assets/images/app_icon.png

Recommended size:
- 1024x1024 px (square, transparent or solid background)

After placing app_icon.png, run:
1) flutter pub get
2) flutter pub run flutter_launcher_icons:main
3) dart run flutter_native_splash:create

This updates:
- Android launcher icons
- iOS app icons
- Web favicon and manifest icons
- Native splash screens (Android/iOS/Web)
