# Convertly — Media Converter & Audio Toolkit

Offline-first Flutter app for converting video and audio on-device. User media
is never uploaded; all processing happens locally.

Target platform for V1 is Android. The architecture is platform-agnostic so iOS
can be added later.

## Architecture

Clean architecture, feature-first. Each feature owns three layers and depends
only inward — presentation → domain ← data. The domain layer holds no Flutter
imports, so business rules stay independent of the UI framework.

```
lib/
├── core/                     Cross-feature building blocks
│   ├── bindings/             App-wide dependency registration
│   ├── constants/            App metadata, storage keys, spacing scale
│   ├── enums/                Shared value types (AudioFormat, AudioQuality)
│   ├── errors/               Failure hierarchy + data-layer exceptions
│   ├── extensions/           BuildContext shorthands
│   ├── routes/               Route names and the central page table
│   ├── services/             StorageService (shared_preferences wrapper)
│   ├── theme/                Material 3 light/dark themes
│   ├── types/                Result<T> — the success/failure return type
│   ├── usecases/             UseCase contracts
│   └── widgets/              Shared widgets (AppLogo, EmptyStateView)
│
├── features/<feature>/
│   ├── domain/               Entities, repository interfaces, use cases
│   │   ├── entities/         Pure Dart, no Flutter types
│   │   ├── repositories/     Abstract contracts
│   │   └── usecases/         One action per class
│   ├── data/                 Implementation details
│   │   ├── models/           Storage representations + mapping to entities
│   │   ├── datasources/      Raw local reads/writes
│   │   └── repositories/     Implements the domain contract, maps errors
│   └── presentation/
│       ├── bindings/         Route-scoped dependency wiring
│       ├── controllers/      View state only — no business rules
│       ├── pages/            Screens
│       └── widgets/          Feature-local widgets
│
└── main.dart
```

### Error handling

Operations that can fail return `Result<T>` (`Success` | `Error`) rather than
throwing. Data sources throw typed exceptions; repositories catch them and map
them to a `Failure`, which carries:

- `message` — safe to show to a user
- `debugMessage` — technical detail, never displayed

This is what keeps raw errors out of the UI.

### State management and DI

GetX provides state, routing and dependency injection in one dependency.
Controllers are registered per route through `Bindings`; only genuinely
app-wide dependencies (`StorageService`, `SettingsController`) are permanent,
and they are registered in `InitialBinding`.

## Current status — Phase 1 complete

Implemented: architecture, theme, routing, splash, onboarding, home dashboard,
bottom-navigation shell, settings skeleton.

Placeholders (built in later phases): Files, Tools actions, conversion.

## Running

```bash
flutter pub get
flutter run
```

## Checks

```bash
dart format lib test
flutter analyze
flutter test
```

## Dependencies

| Package | Purpose |
| --- | --- |
| `get` | State management, routing, DI |
| `shared_preferences` | Onboarding flag and user settings |
| `equatable` | Value equality for entities |

No font or asset is fetched at runtime, so the UI renders fully offline.
