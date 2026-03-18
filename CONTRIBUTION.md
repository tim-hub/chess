## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.x
- Android SDK (for Android builds) or Xcode (for iOS builds)

### Run

```bash
cd chess_app
flutter pub get
flutter run
```

### Build

```bash
# Android
ANDROID_HOME="$HOME/Library/Android/sdk" flutter build apk --release

# iOS
flutter build ios --release
```

## Project Structure

```
chess_app/lib/
├── core/
│   ├── router/       # go_router route definitions
│   ├── theme/        # board themes, colors, text styles
│   └── widgets/      # shared UI components
├── features/
│   ├── audio/        # background music + SFX service
│   ├── game/         # play vs AI (board, moves, Stockfish)
│   ├── puzzles/      # puzzle chapters, solve flow
│   ├── settings/     # preferences screen
│   └── stats/        # games and puzzle stats
└── main.dart
```
