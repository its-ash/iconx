# iconX

A pixel-art icon pack: every app icon redrawn as two-color pixel tiles.

**[Website](https://iconx.itsash.in)** · **[Download APK](https://github.com/its-ash/iconx/releases/latest/download/iconx.apk)** · Get it in **[Ash Store](https://store.itsash.in)**

## Features

- **76 pixel icons**, each a two-color tile on a 16×16 grid with pixel-rounded corners: Google apps,
  system and Motorola apps, popular apps (WhatsApp, Instagram, YouTube, Spotify, Netflix, PhonePe,
  Paytm, Swiggy, Zomato, Flipkart and more) and the Ash Store apps.
- **Works with icon pack launchers**: Nova, Lawnchair, Smart Launcher, Niagara, Action Launcher,
  Hyperion, KISS and others. One-tap apply where the launcher supports it.
- **Apps without an icon** get a dark pixel tile behind their normal icon, so the home screen
  still matches.
- **Your apps**: see which of your apps iconX covers, and share an icon request for the rest.
- **Gallery** with search and a large preview of every icon.
- **Private**: no account, no ads, no tracking. The only network call is the update check in Settings.

## Install

- **Ash Store**: install [Ash Store](https://store.itsash.in) once, then install and update iconX from it.
- **APK**: download the [latest APK](https://github.com/its-ash/iconx/releases/latest/download/iconx.apk) on your phone and open it. Allow your browser to install unknown apps if Android asks.

Requires Android 8.0 (API 26) or later and a launcher that supports icon packs. Most built-in home
screens (Motorola, Samsung, Pixel) do not load icon packs; install Lawnchair or Nova, set it as
your home app, then pick iconX in its icon settings.

## Develop

Needs Flutter ≥ 3.44 and the shared theme package at `../theme`.

```bash
make run       # run on a connected device
make test      # flutter analyze + flutter test (also validates every icon file)
make preview   # render every pack icon into dist/preview.png (needs ImageMagick)
make icon      # regenerate the app's own launcher icon from assets/icon/*.svg
make build     # release APK
make deploy    # bump version, build, tag, push, GitHub release (see store.mk)
```

### Adding an icon

Add a block to a file in `assets/icons/` (format at the top of `google.txt`):

```
[keep]
label = Keep
bg = #F6BF26
fg = #FFFFFF
app = com.google.android.keep/.activities.BrowseActivity
................   16 rows of 16: '#' is the foreground color, '.' the tile color
...
```

Find an app's launcher component with
`adb shell cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER`,
or in iconX's **Your apps** tab. The build turns the files into the PNGs and `appfilter.xml`.

## Release

`make deploy` follows the Ash Store kit (`store.mk`, `store.json`): it bumps the
version in `pubspec.yaml`, builds, commits, tags `vX.Y.Z`, pushes, and publishes
a GitHub release with `iconx.apk`. Ash Store and the website pick up the new
version from that release.

## Project layout

```
assets/icons/*.txt              icon sources (pixel grids, colors, launcher components)
assets/icon/                    the app's own launcher icon (SVG + PNG)
android/app/build.gradle.kts    IconPackTask: .txt -> drawable PNGs, appfilter.xml, drawable.xml
android/app/src/main/
├── AndroidManifest.xml         icon-pack intent filters, package visibility
└── kotlin/.../MainActivity.kt  installed apps, launchers, apply intents, share
lib/
├── main.dart
├── icons/
│   ├── icon_source.dart        parser for assets/icons (same rules as the Gradle task)
│   ├── pixel_icon_view.dart    paints a tile like the launcher PNG
│   └── coverage.dart           which installed apps are themed (pure)
├── platform/launcher_channel.dart
└── screens/                    home (Icons / Your apps / Apply tabs), settings
test/                           parser, real icon files, coverage
```

## License

No license file is included yet.

Built by [itsash.in](https://itsash.in).
