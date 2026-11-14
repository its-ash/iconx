# iconX (package: iconx / com.itsash.iconx)

Pixel-art icon pack for Android launchers. Every icon is a two-color tile: a 16x16 motif on a 20x20
tile with pixel-rounded corners (3 cells cut per corner). The Flutter app is a gallery, a coverage
check of the phone's apps, and apply buttons for launchers.

## Single source of truth: `assets/icons/*.txt`

Format is documented in `lib/icons/icon_format.dart` and at the top of `assets/icons/10-google.txt`:
`group = Title` once per file, then per icon `[name]`, `label`, `bg`, `fg`, one `app = package/Activity`
per launcher component (leading `.` = relative to the package), then 16 rows of 16 characters
(`#` fg, `.` bg). A line matching `[.#]{16}` is a grid row; other lines starting with `#` are comments.
Files load in name order (`10-google`, `20-system`, `30-popular`, `40`-`44` India groups, `50-global`,
`60-phone-makers`, `90-ash-store`), which is the gallery order. A new file must also be added to
`FILES` in `index.html` (a test checks this).

Readers, keep them in sync:
- `android/app/build.gradle.kts` `IconPackTask` (one task per variant, wired with
  `variant.sources.res/assets.addGeneratedSourceDirectory`): writes `drawable-nodpi/<name>.png`
  (240 px, 12 px per cell), `iconback.png` (plain #1F2937 tile, `scale 0.7` for uncovered apps),
  `res/xml/appfilter.xml`, `res/xml/drawable.xml` and copies of both in `assets/`. Fails the build with
  `file:line` on bad input. Nothing generated is checked in.
- `lib/icons/icon_format.dart` `parseIconDefs` + `crossCheck` (pure Dart, no Flutter imports), used by
  `icon_source.dart` (gallery, tests) and `tool/preview.dart`. `pixel_icon_view.dart` paints the tile.
- `index.html` has a small JS parser for the landing-page gallery.

Launchers match `appfilter.xml` by exact component. When an app update renames its launcher activity,
add another `app =` line (the **Your apps** tab lists these as "Icon exists, app changed").
Get components from a phone:
`adb shell cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER`.

## Code layout

- `android/app/src/main/AndroidManifest.xml`: icon-pack discovery intent filters on MainActivity
  (`org.adw.launcher.THEMES`, `com.novalauncher.THEME`, `com.teslacoilsw.launcher.THEME`, ...). No
  `ACTION_PICK_ICON` (the app does not return picked icons). `<queries>` for MAIN/LAUNCHER, HOME and the
  launcher packages.
- `MainActivity.kt`: channel `com.itsash.iconx/launcher`: `apps()` -> `[{label, component}]`,
  `launchers()` -> `[{id, name, installed, isDefault}]`, `apply({id})` -> `applied|opened|failed`
  (Nova and Smart Launcher have apply intents; others are opened), `share({text})`. `Launchers.known`
  lists supported launchers; add a `<package>` query for each.
- `lib/icons/coverage.dart`: themed / package-only / missing apps (pure, tested).
- `lib/screens/`: home (Icons, Your apps, Apply tabs), settings (appearance, then
  `UiUpdateSection(storeId: 'iconx')`, then `UiDeveloperSection()`).

## Commands

- `make run`, `make build`, `make test` (analyze + tests; tests also parse the real icon files and
  check unique names/components and the landing-page file list), `make icon` (app launcher icon from
  `assets/icon/*.svg`), `make clean`.
- `make preview`: validates all icon files and renders them to `dist/preview.png` (`tool/preview.dart` +
  `rsvg-convert`, no Gradle). `make check FILES="assets/icons/40-x.txt" OUT=dist/x` does the same for some
  files (still cross-checked against all). Look at the PNG after editing icons.

## Conventions

- minSdk 26. UI only from `../theme` (read `../theme/COMPONENTS.md`).
- Dart is formatted at 120 columns: `dart format -l 120 <files>`.
- Icons stay two-color pixel art on the grid, like the workspace app icons. Pick a motif that says what
  the app is; do not copy logos in detail.
- Only network use: `UiUpdateSection` in Settings.

## Release (Ash Store)

- `store.json` (id `iconx`, repo its-ash/iconx), `store.mk`, `index.html` + `CNAME`
  (`iconx.itsash.in`). See `../ash-store/store-kit/STORE.md`.
- `make deploy` = bump version → build → commit, tag `vX.Y.Z`, push → GitHub release with
  `iconx.apk` → topics, homepage, Pages. Never create releases, tags or asset names by hand.
- Do not edit `store.mk` here. Edit `../ash-store/store-kit/store.mk`, then run `make store-sync`
  at the workspace root.
