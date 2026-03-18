# Android Build & F-Droid Release — Design Spec

**Date:** 2026-03-17
**App:** Chess3000
**Approach:** Tag-triggered GitHub Actions CI + F-Droid official catalog with AutoUpdateMode

---

## Overview

Release the Chess3000 Flutter app on the official F-Droid catalog. A GitHub Actions workflow builds and signs a release APK on every `v*.*.*` git tag and publishes a GitHub Release. The F-Droid bot detects new tags via `AutoUpdateMode: Version` and builds from source automatically after initial MR acceptance.

**Two separate signing paths:**
- **GitHub Actions** — signs with the developer keystore (via env vars); APK published to GitHub Releases for direct download
- **F-Droid build server** — builds from source; F-Droid re-signs with their own infrastructure key. Developer keystore is irrelevant to F-Droid's build.

---

## Section 1: Android App Configuration

### Package ID
`info.tradeinsight.software.chess3000`
Reverse-domain notation of `tradeinsight.software` + app name `chess3000`.

### Files to change

**`chess_app/android/app/build.gradle`**

Change both `applicationId` and `namespace`:
```groovy
namespace "info.tradeinsight.software.chess3000"
// ...
applicationId "info.tradeinsight.software.chess3000"
```

Add a `signingConfigs.release` block that reads env vars when present, falling back to debug signing otherwise (F-Droid's server has no developer keystore — it re-signs with its own key anyway):
```groovy
signingConfigs {
    release {
        def envKeystore = System.getenv('KEYSTORE_FILE')
        if (envKeystore) {
            storeFile file(envKeystore)
            storePassword System.getenv('KEYSTORE_PASSWORD')
            keyAlias System.getenv('KEY_ALIAS')
            keyPassword System.getenv('KEY_PASSWORD')
        }
    }
}
buildTypes {
    release {
        def envKeystore = System.getenv('KEYSTORE_FILE')
        signingConfig envKeystore ? signingConfigs.release : signingConfigs.debug
    }
}
```
This means: CI (with env vars set) → release-signed APK. F-Droid server (no env vars) → debug-signed, which F-Droid discards and replaces with its own signature.

**`chess_app/android/app/src/main/AndroidManifest.xml`**
- `android:label`: `chess_app` → `Chess3000`

**`chess_app/pubspec.yaml`**
- Version patched by CI before each build. Not manually edited per release.

**`.gitignore` (root — add lines to existing file)**
```
*.jks
*.keystore
```

### versionCode formula
`v1.2.3` → `10203` (major×10000 + minor×100 + patch).

CI patches `pubspec.yaml` with the exact command:
```bash
VERSION=${TAG#v}   # strip leading 'v' → 1.2.3
MAJOR=$(echo $VERSION | cut -d. -f1)
MINOR=$(echo $VERSION | cut -d. -f2)
PATCH=$(echo $VERSION | cut -d. -f3)
VERSION_CODE=$((MAJOR*10000 + MINOR*100 + PATCH))
sed -i "s/^version: .*/version: $VERSION+$VERSION_CODE/" chess_app/pubspec.yaml
```
Flutter reads `version: name+code` from `pubspec.yaml` directly into `flutter.versionName` / `flutter.versionCode` for Gradle.

### Binary assets
`assets/puzzles.db` is committed to the repository (140KB, 450 Lichess puzzles). F-Droid's source build will include it automatically — no generation step needed.

---

## Section 2: Keystore Generation & GitHub Secrets

### One-time local setup
```bash
keytool -genkey -v \
  -keystore chess3000-release.jks \
  -alias chess3000 \
  -keyalg RSA -keysize 2048 \
  -validity 10000

# Base64-encode and copy to clipboard (macOS)
base64 -i chess3000-release.jks | pbcopy
```

**Never commit the `.jks` file.** Root `.gitignore` must include `*.jks` (see Section 1).
Keep a secure offline backup — loss means inability to update the app for users who installed the GitHub Release APK directly (F-Droid APKs are signed by F-Droid and unaffected).

### GitHub Actions secrets (Settings → Secrets → Actions)

| Secret name | Value |
|---|---|
| `KEYSTORE_BASE64` | base64-encoded `.jks` content |
| `KEYSTORE_PASSWORD` | keystore password |
| `KEY_ALIAS` | `chess3000` |
| `KEY_PASSWORD` | key password |

---

## Section 3: GitHub Actions Workflow

**File:** `.github/workflows/release.yml`
**Trigger:** push to tags matching `v*.*.*`

### Workflow-level permissions
```yaml
permissions:
  contents: write   # required for gh release create
```

### Steps
1. `actions/checkout@v4`
2. `actions/setup-java@v4` — Java 17, distribution `temurin`
3. `subosito/flutter-action@v2` — Flutter stable
4. Decode `KEYSTORE_BASE64` → write to `$RUNNER_TEMP/chess3000.jks`
5. Compute `versionCode` from tag and patch `chess_app/pubspec.yaml` (exact command in Section 1)
6. Set env vars for signing:
   ```
   KEYSTORE_FILE=$RUNNER_TEMP/chess3000.jks
   KEYSTORE_PASSWORD=${{ secrets.KEYSTORE_PASSWORD }}
   KEY_ALIAS=${{ secrets.KEY_ALIAS }}
   KEY_PASSWORD=${{ secrets.KEY_PASSWORD }}
   ```
7. `flutter pub get` (run from `chess_app/` directory)
8. `flutter test`
9. `flutter build apk --release` — `build.gradle` reads signing from env vars (set in step 6)
10. `gh release create $TAG chess_app/build/app/outputs/flutter-apk/app-release.apk --generate-notes`

### Signing mechanism
Signing credentials passed as environment variables that `build.gradle` reads via `System.getenv()`. No `-P` flags, no plaintext in `local.properties`. The keystore file lives in `$RUNNER_TEMP` (outside the workspace) and is cleaned up by the runner after the job.

---

## Section 4: F-Droid Metadata

### Store listing (fastlane structure)
```
chess_app/fastlane/metadata/android/en-US/
  title.txt                  → Chess3000
  short_description.txt      → Offline chess with AI and puzzles (≤80 chars)
  full_description.txt       → longer description (≤4000 chars)
  phoneScreenshots/          → at least 2 screenshots (required by F-Droid)
```

### License
The app bundles Stockfish (GPL-3.0). The fdroiddata metadata `License` field must use the most restrictive license: **`GPL-3.0-only`**. Using `MIT` causes MR rejection.

### fdroiddata metadata file
Submitted as a MR to `https://gitlab.com/fdroid/fdroiddata`.
**File path in fdroiddata:** `metadata/info.tradeinsight.software.chess3000.yml`

```yaml
Categories:
  - Games
License: GPL-3.0-only
SourceCode: https://github.com/tim-hub/chess
IssueTracker: https://github.com/tim-hub/chess/issues

AutoName: Chess3000
AutoUpdateMode: Version
UpdateCheckMode: Tags
CurrentVersion: 1.0.0
CurrentVersionCode: 10000

Builds:
  - versionName: 1.0.0
    versionCode: 10000
    commit: v1.0.0
    subdir: chess_app
    flutter: stable
    build: flutter build apk --release
    output: build/app/outputs/flutter-apk/app-release.apk
    prebuild: flutter pub get
```

Note: no `sudo` block — F-Droid's Android build environment already provides the Android SDK, NDK, and Flutter. F-Droid re-signs the APK with its own key after building; the `signingConfigs.debug` fallback in `build.gradle` ensures the build succeeds on F-Droid's server.

### F-Droid submission process (one-time)
1. Fork `https://gitlab.com/fdroid/fdroiddata`
2. Add `metadata/info.tradeinsight.software.chess3000.yml`
3. Run `fdroid lint metadata/info.tradeinsight.software.chess3000.yml` locally to validate
4. Open MR — review typically takes 2–8 weeks
5. After merge: every future `v*.*.*` tag is auto-detected and built by F-Droid's infrastructure

---

## Out of scope
- iOS release
- Self-hosted F-Droid repository
- Play Store / other app stores
- In-app purchases or analytics (app has none)

---

## Key constraints
- F-Droid builds from source and re-signs with its own key — developer keystore only affects GitHub Release APKs
- All dependencies must remain FOSS; Stockfish (GPL-3.0) is the most restrictive license — app license must be `GPL-3.0-only`
- Keystore must never be committed — loss only affects users who installed the GitHub Release APK directly (not F-Droid users)
