# Cairn

An offline hiking log for six Philippine peaks. Mark a peak climbed, keep the date, who you went with, notes and photos, and earn a badge for it.

**Built and checked on Android.** It also builds and runs on the iOS simulator, where every screen has been walked in both themes. No iPhone has ever run it.

## What it does

- Holds a fixed list of six peaks with real figures: elevation, difficulty, hours to the summit, and where the trail starts
- Marks one climbed with a date, companions, notes and photos, all optional except the date
- Turns that peak's card from grey to colour on the list, so progress reads without a counter
- Unlocks a badge for the peak, plus a milestone badge at the third and the sixth
- Builds a card on the phone that you can send to somebody
- Works with no account, no sign-in, and no network. Nothing in the app calls out

## How it looks

Screenshots pending.

## Accessibility

The most deliberate part of the app.

- **Shape carries the meaning, not colour.** A milestone badge is a scalloped seal and a peak badge is a plain circle, so the two stay apart for anyone who cannot tell the colours apart. There is a test that renders them in greyscale and fails if they stop being distinguishable
- **Every colour pair is measured.** 46 of them against WCAG AA, with the numbers written down. Six were failing and were fixed by moving four palette values
- **Nothing truncates.** No ellipsis appears anywhere in the app. A `…` hides exactly the part the reader wanted, and it makes a data problem look like a design choice. Where a value did not fit, the data or the layout changed instead
- Text scales with the system setting, and every screen sits inside a `SafeArea`

## How it is built

Flutter with Riverpod for state, Drift over SQLite for storage, and go_router for navigation.

One rule holds the layers apart: **UI reads a provider, a provider reads a DAO, a DAO owns the Drift table.** No screen touches the database. A test walks the imports and fails if anything crosses a layer.

Decisions worth knowing about:

- **A climb is a calendar day, not a timestamp.** 11 August stays 11 August in any timezone, because the column's converter drops everything below the day
- **Badges unlock inside the climb's own write.** One transaction, so a save that earns two badges is still one thing that happened, and a failure part way leaves neither
- **Photos are stored as bare filenames**, never paths. The app container's location changes between installs, so the directory is looked up again on every render
- **Photos are capped at 2048px on the long edge** on the way in. On a real device that turned 17.6 MB of photos into 6.8 MB with no visible difference at phone size

## Run it

Needs Flutter 3.44 or newer, on Dart 3.12.

```
flutter pub get
flutter run
```

The tests:

```
flutter test
```

Screenshots of every route in both themes, which needs a running Android emulator:

```
tool/screenshots.sh
```

On an iOS simulator, drive the same target by hand. The script itself is Android-only because it picks its device through `adb`, but the Dart it runs is not:

```
flutter drive --device-id <simulator udid> \
  --keep-app-running \
  --driver test_driver/integration_test.dart \
  --target integration_test/screenshot_test.dart
```

It wants a climb already logged on the device, and it says so if there is none.

## Numbers

| | |
|---|---|
| Tests | 594, against 62 source files |
| Cold start | 253 ms on the phone it was built for, an Infinix on Android 15 |
| Release APK | 21.5 MB for the arm64 split. The fat APK is 62.1 MB |
| Network calls | None |

## What it does not do

- **No iPhone has run it.** The simulator covers the screens, the storage, the fonts, the safe areas and the back swipe, and it cannot speak for a real device: battery, thermals, a photo library with thousands of images in it, HEIC files straight off a phone camera, and anything about shipping to the App Store are all untested
- **Release builds sign with debug keys**, so no APK from this repo is fit to hand around
- **Peak photography is deliberately missing.** Cards carry a placeholder mark for now. The desaturation treatment already runs through `ColorFiltered`, so photographs drop in without a code change
- **No continuous integration.** The tests run on a machine, by hand

## Licence

MIT, in [LICENSE](LICENSE).

Manrope is bundled under the SIL Open Font License, with the full licence in `assets/fonts/OFL.txt`.
