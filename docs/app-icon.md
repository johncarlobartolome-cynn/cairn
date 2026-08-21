# The launcher icon

The icon is the app's own mark, three stacked stones, cream on the brand green.
The same mark sits on a climbed card, in the nav and on the share card, so the
thing on the home screen is the thing inside the app.

Ground `#1E3A2B` (`brand`), glyph `#F4F1EA` (`onBrand`). Both tokens come from the
design spec; the icon invents nothing.

## Regenerate it

```
tool/icons.sh
```

That is the whole answer. It runs three steps and everything it writes is
committed:

| Step | What it does |
|---|---|
| `tool/icon/generate_icon_sources.dart` | Draws the three 1024 masters into `assets/icon/` |
| `flutter_launcher_icons` | Fans them out to every Android density and every iOS slot, and writes the adaptive-icon XML |
| `tool/icon/check_ios_opaque.dart` | Fails if an iOS slot is the wrong size or carries an alpha channel |

Nothing under `assets/icon/` is bundled into the app. It is not listed under
`flutter: assets:` in `pubspec.yaml`, so the masters live in the repository and
not in the APK.

## The three masters

| File | What it is |
|---|---|
| `app_icon.png` | Cream mark on brand green, three channels and no alpha. Feeds the iOS set and the legacy Android mipmaps |
| `app_icon_foreground.png` | The mark alone on transparency, drawn to the adaptive safe zone. The adaptive foreground layer |
| `app_icon_monochrome.png` | The same shape in white. Android 13 tints it for a themed icon |

The adaptive background is a colour, `#1E3A2B`, written to
`res/values/colors.xml` rather than to a PNG. It is a flat field, and a
one-colour image is only a file that can be resampled wrong.

## Why a script instead of a drawing

The mark already exists as a `CustomPainter` in
`lib/shared/widgets/cairn_mark.dart`. Redrawing it in an image editor would
leave two copies of one shape, drifting apart at the first tweak. The script
restates the only thing the painter holds that a PNG cannot infer, the stone
geometry, and rasterises from that.

The stone rectangles and their radii are duplicated in the script, and the
duplication is named in a comment there. The painter's copies are `Rect`s from
`dart:ui`, which only exists inside a Flutter engine, and a plain `dart run`
script has no way to start one. **Change one, change the other, then look at the
result.**

Coverage per pixel comes from the signed distance to each rounded rectangle
rather than from counting subsamples. A distance gives a smooth edge at any size;
subsamples give a fixed number of alpha steps, and on a 1024 canvas those steps
show as banding on the corners.

## The two numbers that matter

**The full icon spans 0.75 of the canvas**, so the drawn stones cover 57.5% of it
and the furthest corner sits 40% out from the centre. A round launcher mask cuts
at 50%, so one file survives being masked square, round or squircle.

**The adaptive foreground spans 0.56.** An adaptive icon is authored on a 108dp
canvas of which only the middle 66dp is guaranteed to survive the mask, which is
a circle of radius 30.6% of the canvas. The mark's furthest corner is 12.85 grid
units from its centre, landing at 30.0% at this span. Draw it larger and a
circular mask takes the corners off the bottom stone.

`adaptive_icon_foreground_inset: 0` is in the config for the same reason. The
package otherwise wraps the foreground in a 16% inset, which would shrink a mark
already drawn to the safe zone to two thirds of the size it can be. One place
owns the safe-zone maths, and it is the script.

## Why flutter_launcher_icons

The fan-out is a solved problem with a maintained package, and the parts of it
that are easy to get wrong by hand are exactly the parts it does: eleven Android
files across five densities, twenty-five iOS slots and their `Contents.json`, and
the adaptive-icon XML. The drawing stays ours because the mark is ours; the
bookkeeping does not need to be.

It has one bug worth knowing about. It rewrites **every** line containing
`ASSETCATALOG` in the Xcode build configuration to the icon set's name, which
turns `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES` into
`= AppIcon`. Xcode still builds, so the change is silent, and it has nothing to
do with the icon: the set was already called `AppIcon`. `tool/icons.sh` puts the
line back, so the script leaves `project.pbxproj` exactly as it found it.

## iOS icons carry no alpha

App Store Connect rejects an icon with an alpha channel, and it rejects it at
upload, long after anybody looked at the picture. On a simulator a transparent
icon simply renders black behind the glyph, so nothing warns you.

Two things hold the guarantee. `app_icon.png` is written with three channels, so
there is no alpha to lose an argument about later, and `remove_alpha_ios: true`
flattens anything that slips through. `tool/icon/check_ios_opaque.dart` then
decodes all 25 generated files and fails the run if any of them has an alpha
channel or is the wrong pixel size.

## What it looks like, and what iOS 26 does to it

Checked on an Android 16 emulator and an iOS 26.2 simulator, at both the launcher
and the app drawer.

- **Android, circular mask:** reads as three stones with the gaps intact.
  Nothing is clipped
- **Android themed icons:** the monochrome layer tints correctly and keeps the
  three bands
- **Smallest density:** the mark still reads at 36px. The gaps narrow to about a
  pixel there and start to close, but the silhouette is a stack rather than a
  blob
- **iOS 26** applies its own Liquid Glass treatment to a flat icon: the stones
  pick up a bevel and a soft highlight. It is Apple's automatic conversion, not
  something in the asset, and it reads correctly in both light and dark. Shipping
  an Icon Composer document would take control of it, and would be its own ticket
