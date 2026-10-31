# Dab Browser & Multi-Threaded Download Manager

[![Flutter](https://img.shields.io/badge/Flutter-3.x_Stable-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Engine](https://img.shields.io/badge/Engine-Mozilla_GeckoView-FF7139?logo=firefox)](https://wiki.mozilla.org/Mobile/GeckoView)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://www.android.com)

---

## Project Info

Dab Browser is a high-performance Android browser powered by Mozilla GeckoView, featuring a built-in, 1DM+-style multi-threaded segment download manager. It delivers desktop-grade web rendering, standard web extension compatibility, enhanced privacy protections, and accelerated multi-part network downloading within a unified, modern Flutter application.

Designed with **Material 3 Expressive** and full **Material You (Dynamic Color)** theming, the application prioritizes speed, gesture ergonomics, and architectural cleanliness.

---

## Tech Stack

| Category | Technology / Package | Purpose |
|---|---|---|
| **Framework** | Flutter (Android target) | Cross-platform UI toolkit |
| **Language** | Dart 3.x | Type-safe language with sound null safety |
| **Browser Engine** | `webview_flutter_geckoview` / `webview_flutter` | Mozilla GeckoView embedding & web engine |
| **State Management** | `flutter_riverpod` + `riverpod_annotation` | Compile-safe reactive state architecture |
| **Navigation** | `go_router` | Declarative routing with Android predictive back |
| **Networking & Downloads** | `dio`, `path_provider` | Multi-segmented downloading & API communication |
| **Secure Storage** | `flutter_secure_storage` | Android Keystore encrypted credential storage |
| **Design & UI Tokens** | `dynamic_color`, `phosphoricons_flutter`, `google_fonts` | Material You wallpaper-driven palette, Phosphor icons, variable fonts |

---

## Folder Structure

```
browser/
├── android/                         # Android native project files & Manifest
├── env/                             # Environment configuration files (--dart-define-from-file)
│   ├── dev.example.json
│   └── prod.example.json
├── lib/
│   ├── app.dart                     # MaterialApp.router with DynamicColorBuilder
│   ├── main.dart                    # Application entry point with ProviderScope
│   ├── config/                      # Core runtime configurations
│   │   ├── dio_client.dart          # Centralized Dio instance with redaction interceptor
│   │   ├── env.dart                 # Typed environment reader
│   │   └── router.dart              # GoRouter route declarations
│   ├── features/                    # Domain features (browser, downloader, settings)
│   ├── shared/                      # Cross-feature reusable modules
│   │   ├── models/
│   │   ├── utils/
│   │   └── widgets/
│   └── theme/                       # Design system & tokens
│       ├── app_theme.dart           # M3 Expressive ThemeData constructor
│       ├── shapes/                  # Custom ShapeBorder definitions
│       └── tokens/                  # Dart design token constants
│           ├── app_colors.dart
│           ├── app_motion.dart
│           ├── app_radius.dart
│           ├── app_shapes.dart
│           ├── app_spacing.dart
│           └── app_typography.dart
├── reference/                       # Design documents & visual references
│   ├── DESIGN_MOBILE.md             # Anti-slop baseline & M3 Expressive specs
│   └── screenshots_mobile/
├── analysis_options.yaml            # Linter rules & manual file size guidelines
├── progress.md                      # Session progress log (git-ignored)
├── pubspec.yaml                     # Dependency specification
└── task.md                          # Active task tracker
```

---

## How to Use

### 1. Prerequisites
- **Flutter SDK**: 3.x stable channel installed and added to `PATH`.
- **Android SDK**: Android 13+ (API 33+) recommended with build-tools.
- **Java**: JDK 17+.

### 2. Configure Environment
Create an environment file from the provided template:
```bash
cp env/dev.example.json env/dev.json
```

### 3. Fetch Dependencies
After reviewing and approving the dependency lock:
```bash
flutter pub get
```

### 4. Run the Project
To run in development mode with dynamic configuration:
```bash
flutter run --dart-define-from-file=env/dev.json
```

---

## License & Distribution

This project is licensed under the [MIT License](LICENSE).
All rights reserved for project branding and proprietary GeckoView integration components.
