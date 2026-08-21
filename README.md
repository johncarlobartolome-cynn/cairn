# Cairn

An offline hiking log for six Philippine peaks. Mark a peak climbed, keep the date, who you went with, notes and photos, and earn a badge for it.

**Built and checked on Android.** It also builds and runs on the iOS simulator, where every screen has been walked in both themes. No iPhone has ever run it.

## What it does

- Holds a fixed list of six peaks with real figures: elevation, difficulty, hours to the summit, and where the trail starts
- Marks one climbed with a date, companions, notes and photos, all optional except the date
- Turns that peak's card from grey to colour on the list, so progress reads without a counter. All six fit one Android screen, which is the size the layout was measured against. On a shorter screen the last row takes a small scroll
- Unlocks a badge for the peak, plus a milestone badge at the third and the sixth
- Builds a card on the phone that you can send to somebody
- Works with no account, no sign-in, and no network. Nothing in the app calls out

## How it looks

Captured on an Android emulator in the light theme. Everything on these screens is seeded demo data, written by the capture harness so the pictures show a library part way done. `tool/screenshots.sh readme` builds that state and takes the shots, so the same three screens come back on anybody's machine.

| Peaks | Peak detail | Badges |
|---|---|---|
| ![The peaks list. Six peak cards in a two-column grid. Batulao, Kabunian and Ulap are in full green with a small cairn mark in the top corner of each. Daraitan, Mariglem and Pulag are washed out grey with no mark. A label beside the heading reads 3 of 6 climbed, over a bar filled halfway.](docs/screenshots/peaks-list.png) | ![Peak detail for Mt. Kabunian. Under the name it says Benguet, 4 hours to the summit. Two tiles hold 1,789 m elevation and Moderate difficulty. Below them the jump-off point reads as two plain sentences, then a full-width Mark climbed button, then one climb logged on 4 July 2026 with Mara and Enzo.](docs/screenshots/peak-detail.png) | ![The badges grid. A tile reads 5 of 9 earned. Under a Milestones label, First climb and Three peaks are gold scalloped seals carrying the date they unlocked, and All peaks is that same scalloped shape drawn as a thin outline. Under a Peaks label, an earned peak badge is a filled circle and a locked one is an outlined circle.](docs/screenshots/badges-grid.png) |
| Six cards, two to a row. A climbed peak is in full colour and carries the cairn mark while the rest are washed out, so how far along you are reads off the grid itself. | One peak: where it is, the two figures that decide whether you go, where the trail starts, the button that logs a climb, and every climb already logged against it. | Five of nine earned. A milestone is a scalloped seal and a peak badge is a plain circle, so the two are still told apart once the colour is taken away. |

Peak photography has not been added yet, so a card carries a flat block where the photo will go. The badges grid scrolls, and its last row sits under the floating nav until you move it.

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

That set shoots whatever the device holds, so it wants a climb already logged there, and it says so if there is none. The three pictures under How it looks come from a library the harness seeds itself, which is why they are the same on any emulator:

```
tool/screenshots.sh readme
```

Both sets write into `screenshots/`, which is gitignored. `docs/screenshots/` holds the three curated and downscaled images the README uses, and those are committed.

On an iOS simulator, drive the same target by hand. The script itself is Android-only because it picks its device through `adb`, but the Dart it runs is not:

```
flutter drive --device-id <simulator udid> \
  --keep-app-running \
  --driver test_driver/integration_test.dart \
  --target integration_test/screenshot_test.dart
```

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
