# Day Architect — Flutter Project

This is the starter Flutter codebase for Day Architect, matching the Figma mockup
1:1 — same colors, fonts, layout, and 5 screens.

## Requirements

1. Install Flutter SDK: https://docs.flutter.dev/get-started/install
   (Choose your OS — Windows, macOS, or Linux)
2. Install Android Studio (for the Android emulator) OR have a physical phone
   with USB debugging enabled
3. Verify your setup by running:
   ```
   flutter doctor
   ```
   Fix any ❌ items it flags before continuing.

## Running the project

```bash
# 1. Navigate into the project folder
cd day_architect

# 2. Install dependencies
flutter pub get

# 3. Run on a connected device or emulator
flutter run
```

If you have multiple devices/emulators connected, run `flutter devices` first,
then `flutter run -d <device_id>` to pick one.

## Project structure

```
day_architect/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── theme/
│   │   └── app_theme.dart        # All colors, fonts, gradients (design tokens)
│   ├── widgets/
│   │   └── app_widgets.dart      # Reusable components (buttons, cards, nav bar)
│   └── screens/
│       ├── onboarding_screen.dart
│       ├── today_screen.dart
│       ├── focus_screen.dart
│       ├── winddown_screen.dart
│       └── progress_screen.dart
└── pubspec.yaml                  # Dependencies
```

## What's already working

- All 5 screens are built and navigable (tap the bottom nav bar or "Get Started")
- Fonts (Lora + Poppins) load automatically via `google_fonts` — no manual font
  files needed
- All colors match the Figma design system exactly (see `app_theme.dart`)
- The Focus Mode timer ring is a custom-painted widget — no external chart
  library dependency

## What's still just UI (not yet functional — good next tasks for your team)

- [ ] Task data is hardcoded — connect to local storage (e.g. `sqflite` or
      `shared_preferences`) or Firebase so schedules persist
- [ ] The Focus Mode timer doesn't actually count down yet — needs a `Timer`
      or `Ticker` wired up
- [ ] The "app blocking" feature needs a platform-specific plugin (Android
      only realistically — look into `usage_stats` or a native `MethodChannel`
      for restricting app access; this is the most technically advanced
      feature, tackle it last)
- [ ] Notifications for wind-down / bedtime reminders — use the
      `flutter_local_notifications` package
- [ ] User accounts / auth — Firebase Authentication is the easiest path
- [ ] Add-task form behind the "+" button on the Today screen

## Suggested order to build in

1. Get the app running and navigable (already done ✅)
2. Wire up local storage so tasks persist between app restarts
3. Make the Focus Mode timer actually count down
4. Add local notifications for wind-down reminders
5. Tackle app-blocking last — it's the most complex, OS-specific feature
