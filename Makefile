STORE_ID := iconx

.PHONY: run build clean test perf icon preview check

run:
	flutter pub get && flutter run

build:
	flutter pub get && flutter build apk --release

test:
	flutter analyze && flutter test

# Gallery scroll frame timings on a connected phone (profile build). Results in
# build/integration_response_data.json (frame build/raster ms, missed frames).
# flutter drive uninstalls the app when it ends, so the release build is put back after.
perf:
	-flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart --target=integration_test/scroll_perf_test.dart
	flutter build apk --release && adb install -r build/app/outputs/flutter-apk/app-release.apk

# Launcher icon: assets/icon/*.svg -> *-1024.png -> mipmaps.
icon:
	cd assets/icon && for f in logo logo_foreground logo_background; do rsvg-convert -w 1024 -h 1024 $$f.svg -o $$f-1024.png; done
	dart run flutter_launcher_icons

# Validates every icon file (same rules as the app and the Gradle build, plus duplicate names and
# components across files) and renders all icons into dist/preview.png. Needs rsvg-convert.
preview:
	dart run tool/preview.dart -o dist/preview.svg
	rsvg-convert dist/preview.svg -o dist/preview.png
	@echo "dist/preview.png"

# Same for some files only: make check FILES="assets/icons/40-x.txt" OUT=dist/x
check:
	dart run tool/preview.dart $(FILES) -o $(or $(OUT),dist/check).svg
	rsvg-convert $(or $(OUT),dist/check).svg -o $(or $(OUT),dist/check).png
	@echo "$(or $(OUT),dist/check).png"

clean:
	flutter clean
	rm -rf dist

# deploy, release, bump, store-check, store-meta, version
include store.mk
