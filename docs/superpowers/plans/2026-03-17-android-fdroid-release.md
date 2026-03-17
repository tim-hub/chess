# Android F-Droid Release Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure Chess3000 for a signed Android release and set up automated publishing to GitHub Releases + F-Droid official catalog.

**Architecture:** GitHub Actions triggers on `v*.*.*` tags, computes versionCode from the tag, patches `pubspec.yaml`, builds a signed APK via env-var-injected keystore, and publishes to GitHub Releases. F-Droid detects new tags via `AutoUpdateMode: Version` and builds from source independently, re-signing with its own key.

**Tech Stack:** Flutter stable, Gradle (Groovy), GitHub Actions, `gh` CLI, `keytool` (JDK), F-Droid fdroiddata YAML

**Spec:** `docs/superpowers/specs/2026-03-17-android-fdroid-release-design.md`

---

## Chunk 1: Android App Configuration

### Task 1: Update `build.gradle` — package ID, namespace, and signing config

**Files:**
- Modify: `chess_app/android/app/build.gradle`

Current state: `applicationId "com.chess.chess_app"`, `namespace "com.chess.chess_app"`, release build uses `signingConfigs.debug`.

- [ ] **Step 1: Replace `namespace` and `applicationId`**

In `chess_app/android/app/build.gradle`, make these two changes:

```groovy
// Line 29 — change namespace
namespace "software.tradeinsight.chess3000"
```

```groovy
// Inside defaultConfig — change applicationId
applicationId "software.tradeinsight.chess3000"
```

- [ ] **Step 2: Add `signingConfigs.release` block and update `buildTypes.release`**

Inside the `android { }` block, before `defaultConfig`, add the `signingConfigs` block. Then replace `buildTypes.release`:

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
```

Replace `buildTypes.release`:
```groovy
    buildTypes {
        release {
            def envKeystore = System.getenv('KEYSTORE_FILE')
            signingConfig envKeystore ? signingConfigs.release : signingConfigs.debug
        }
    }
```

When `KEYSTORE_FILE` env var is present (GitHub Actions): uses developer keystore.
When absent (F-Droid's build server): falls back to debug signing — F-Droid discards this and re-signs with its own key.

- [ ] **Step 3: Verify the build compiles locally**

```bash
cd chess_app
flutter build apk --debug
```

Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk` — confirms Gradle config is valid. Debug build avoids needing the release keystore locally.

- [ ] **Step 4: Commit**

```bash
git add chess_app/android/app/build.gradle
git commit -m "chore(android): set app ID to software.tradeinsight.chess3000 and add env-var signing config"
```

---

### Task 2: Update `AndroidManifest.xml` — app display name

**Files:**
- Modify: `chess_app/android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Change `android:label`**

```xml
<!-- Change this line -->
android:label="chess_app"
<!-- To -->
android:label="Chess3000"
```

- [ ] **Step 2: Commit**

```bash
git add chess_app/android/app/src/main/AndroidManifest.xml
git commit -m "chore(android): rename app label to Chess3000"
```

---

### Task 3: Update `.gitignore` — protect keystore files

**Files:**
- Modify: `.gitignore` (root)

- [ ] **Step 1: Add keystore patterns**

Append to the root `.gitignore`:
```
*.jks
*.keystore
```

- [ ] **Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: add keystore patterns to .gitignore"
```

---

## Chunk 2: GitHub Actions Release Workflow

### Task 4: One-time keystore generation (local, manual)

This task runs on the developer's machine once and is NOT committed.

- [ ] **Step 1: Generate the keystore**

```bash
# Run from any directory OUTSIDE the repo, or the repo root (covered by .gitignore)
keytool -genkey -v \
  -keystore chess3000-release.jks \
  -alias chess3000 \
  -keyalg RSA -keysize 2048 \
  -validity 10000
```

When prompted:
- First/last name, org, city, country: use real values (embedded in certificate)
- Keystore password: choose a strong password, save it securely (password manager)
- Key password: can be the same as keystore password

- [ ] **Step 2: Base64-encode and copy to clipboard**

```bash
# macOS
base64 -i chess3000-release.jks | pbcopy

# Linux
base64 chess3000-release.jks | xclip -selection clipboard
```

- [ ] **Step 3: Add 4 secrets to GitHub**

Go to: `https://github.com/tim-hub/chess` → Settings → Secrets and variables → Actions → New repository secret

| Name | Value |
|---|---|
| `KEYSTORE_BASE64` | paste from clipboard |
| `KEYSTORE_PASSWORD` | keystore password from step 1 |
| `KEY_ALIAS` | `chess3000` |
| `KEY_PASSWORD` | key password from step 1 |

- [ ] **Step 4: Store the `.jks` file in a secure offline location**

Copy `chess3000-release.jks` to a password manager (e.g., as a file attachment in 1Password/Bitwarden) or an encrypted drive. Loss of this file means GitHub Release APKs can no longer be updated for users who installed that version.

---

### Task 5: Create the GitHub Actions release workflow

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Create the workflow directory**

```bash
mkdir -p .github/workflows
```

- [ ] **Step 2: Write the workflow file**

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

permissions:
  contents: write   # required for gh release create

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Java 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Decode keystore
        run: |
          echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode > $RUNNER_TEMP/chess3000.jks

      - name: Compute versionCode and patch pubspec.yaml
        run: |
          TAG=${GITHUB_REF_NAME}
          VERSION=${TAG#v}
          MAJOR=$(echo $VERSION | cut -d. -f1)
          MINOR=$(echo $VERSION | cut -d. -f2)
          PATCH=$(echo $VERSION | cut -d. -f3)
          VERSION_CODE=$((MAJOR*10000 + MINOR*100 + PATCH))
          sed -i "s/^version: .*/version: $VERSION+$VERSION_CODE/" chess_app/pubspec.yaml
          echo "Patched pubspec.yaml to version: $VERSION+$VERSION_CODE"

      - name: Flutter pub get
        working-directory: chess_app
        run: flutter pub get

      - name: Flutter test
        working-directory: chess_app
        run: flutter test

      - name: Build release APK
        working-directory: chess_app
        env:
          KEYSTORE_FILE: ${{ runner.temp }}/chess3000.jks
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
        run: flutter build apk --release

      - name: Create GitHub Release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh release create $GITHUB_REF_NAME \
            chess_app/build/app/outputs/flutter-apk/app-release.apk \
            --title "Chess3000 $GITHUB_REF_NAME" \
            --generate-notes
```

- [ ] **Step 3: Validate workflow YAML syntax**

```bash
# Install actionlint if not present
brew install actionlint   # macOS
# or: go install github.com/rhysd/actionlint/cmd/actionlint@latest

actionlint .github/workflows/release.yml
```

Expected: no errors output.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: add tag-triggered release workflow with APK signing"
```

---

### Task 6: Smoke test the workflow

- [ ] **Step 1: Push a test tag to trigger the workflow**

```bash
git tag v1.0.0
git push origin v1.0.0
```

- [ ] **Step 2: Monitor the workflow run**

Go to `https://github.com/tim-hub/chess/actions` → watch the `Release` workflow.

Expected: all steps pass, a GitHub Release `v1.0.0` is created with `app-release.apk` attached.

- [ ] **Step 3: Verify the APK is signed with the release key**

Download `app-release.apk` from the GitHub Release. Then:

```bash
# Check signing certificate
keytool -printcert -jarfile app-release.apk
```

Expected: certificate owner matches the values entered during keystore generation (not "Android Debug").

---

## Chunk 3: Store Listing & F-Droid Metadata

### Task 7: Create fastlane store listing content

F-Droid reads the fastlane metadata directory for the store listing (description, screenshots).

**Files:**
- Create: `chess_app/fastlane/metadata/android/en-US/title.txt`
- Create: `chess_app/fastlane/metadata/android/en-US/short_description.txt`
- Create: `chess_app/fastlane/metadata/android/en-US/full_description.txt`
- Create: `chess_app/fastlane/metadata/android/en-US/phoneScreenshots/` (directory, add 2+ screenshots)

- [ ] **Step 1: Create the directory structure**

```bash
mkdir -p chess_app/fastlane/metadata/android/en-US/phoneScreenshots
```

- [ ] **Step 2: Write `title.txt`**

```
Chess3000
```

- [ ] **Step 3: Write `short_description.txt`** (≤80 characters)

```
Offline chess with AI opponent and tactical puzzles
```

- [ ] **Step 4: Write `full_description.txt`** (≤4000 characters)

```
Chess3000 is a fully offline chess app — no account, no internet required.

Features:
• Play against a built-in Stockfish AI at multiple difficulty levels
• Solve 450 tactical puzzles across 9 themed chapters (Checkmate in 1, Forks, Pins, Skewers, and more)
• Earn stars and unlock chapters as you improve
• Pawn promotion, castling, and all standard rules fully supported
• Two piece sets: CBurnett and Merida
• Move sound effects

All puzzles sourced from the Lichess open puzzle database (CC0).
Stockfish engine is GPL-3.0. Source code: https://github.com/tim-hub/chess
```

- [ ] **Step 5: Add screenshots**

Take at least 2 screenshots on an Android device or emulator:
1. Home screen
2. A game in progress or puzzle screen

Copy them to `chess_app/fastlane/metadata/android/en-US/phoneScreenshots/` as `01.png`, `02.png`.

- [ ] **Step 6: Commit**

```bash
git add chess_app/fastlane/
git commit -m "chore: add F-Droid store listing metadata"
```

---

### Task 8: Prepare fdroiddata submission YAML

This file is submitted to the `fdroid/fdroiddata` GitLab repository, **not** this repo. Create it locally for review before submitting the MR.

- [ ] **Step 1: Install `fdroid` tool for local linting**

```bash
pip install fdroidserver
# or on Debian/Ubuntu:
# sudo apt install fdroidserver
```

- [ ] **Step 2: Create the metadata file locally**

Create a temporary file `software.tradeinsight.chess3000.yml` (anywhere on your machine):

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
    output: build/app/outputs/flutter-apk/app-release.apk
    prebuild: flutter pub get
```

`build:` is intentionally omitted. The `flutter: stable` key tells F-Droid's server to invoke `flutter build apk` internally. Adding a `build:` field would attempt to run `flutter` as a bare shell command before the toolchain is ready, causing a failure.

- [ ] **Step 3: Lint the metadata file**

The `fdroid lint` command must be run from inside a cloned fdroiddata repo, not against a bare file path:

```bash
# Clone your fork of fdroiddata and copy the file in first
cp software.tradeinsight.chess3000.yml metadata/
# Then lint using the app ID (no .yml extension, no path prefix)
fdroid lint software.tradeinsight.chess3000
```

Expected: no errors.

- [ ] **Step 4: Submit MR to fdroiddata**

```bash
# Fork https://gitlab.com/fdroid/fdroiddata on GitLab, then:
git clone git@gitlab.com:<your-username>/fdroiddata.git
cd fdroiddata
# Copy the metadata file (already created in Step 2, linted in Step 3)
cp /path/to/software.tradeinsight.chess3000.yml metadata/
git checkout -b add-chess3000
git add metadata/software.tradeinsight.chess3000.yml
git commit -m "New app: Chess3000 (software.tradeinsight.chess3000)"
git push origin add-chess3000
# Open MR at https://gitlab.com/fdroid/fdroiddata
```

Review timeline: 2–8 weeks. The F-Droid team may request changes to the metadata YAML.

- [ ] **Step 5: After MR is merged — verify automatic updates work**

Push a new tag (e.g., `v1.0.1`) and verify that F-Droid's build bot creates a new build entry automatically. Check `https://f-droid.org/packages/software.tradeinsight.chess3000/` for the new version.

---

## Summary of Files Changed

| File | Action |
|---|---|
| `chess_app/android/app/build.gradle` | Modify — new package ID, signing config |
| `chess_app/android/app/src/main/AndroidManifest.xml` | Modify — app label |
| `.gitignore` | Modify — add `*.jks`, `*.keystore` |
| `.github/workflows/release.yml` | Create — CI release pipeline |
| `chess_app/fastlane/metadata/android/en-US/title.txt` | Create |
| `chess_app/fastlane/metadata/android/en-US/short_description.txt` | Create |
| `chess_app/fastlane/metadata/android/en-US/full_description.txt` | Create |
| `chess_app/fastlane/metadata/android/en-US/phoneScreenshots/` | Create — add 2+ screenshots |
| `software.tradeinsight.chess3000.yml` | Create locally → submit to fdroiddata (external repo) |

## Manual steps (cannot be automated)

- Generate keystore with `keytool` (one-time)
- Add 4 GitHub Actions secrets
- Store keystore backup securely
- Take and add screenshots
- Fork fdroiddata and submit MR
