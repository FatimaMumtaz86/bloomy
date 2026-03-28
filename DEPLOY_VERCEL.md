# Vercel Deployment (Web + Privacy Policy + APK CTA)

This repo includes a prebuilt static web bundle at `web_release/`.

## Deploy in 2 minutes

1. Push this repo to GitHub.
2. In Vercel, click **New Project** and import this repo.
3. In project settings:
   - Framework Preset: `Other`
   - Build Command: *(leave empty)*
   - Output Directory: `web_release`
4. Deploy.

## URLs after deploy

- App: `https://<your-domain>/`
- Privacy Policy (for Play Console): `https://<your-domain>/privacy-policy.html`

## APK button

The web app includes a floating **Download Android APK** button configured to:

`https://github.com/FatimaMumtaz86/bloomy/releases/latest/download/app-release.apk`

Upload each new APK to GitHub Releases using this filename:
- `app-release.apk`

Then the download button will always point to latest release.

## Trust metadata shown on site

- Version: `1.0.0+1`
- SHA1: `9fe2478497cafe44d968af7992554002e58b440a`
