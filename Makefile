STORE_ID := iconx

.PHONY: run build clean test icon preview

run:
	flutter pub get && flutter run

build:
	flutter pub get && flutter build apk --release

test:
	flutter analyze && flutter test

# Launcher icon: assets/icon/*.svg -> *-1024.png -> mipmaps.
icon:
	cd assets/icon && for f in logo logo_foreground logo_background; do rsvg-convert -w 1024 -h 1024 $$f.svg -o $$f-1024.png; done
	dart run flutter_launcher_icons

# Renders every pack icon (from assets/icons/*.txt) into dist/preview.png to check the pixel art.
# Uses Flutter's JDK: a newer system JDK breaks the Android Gradle build. Needs ImageMagick.
preview:
	flutter pub get >/dev/null
	J=$$(flutter doctor -v 2>/dev/null | sed -n 's/.*Java binary at: \(.*\)\/bin\/java.*/\1/p' | head -1); \
	cd android && JAVA_HOME="$$J" ./gradlew -q :app:generateDebugIconPack
	mkdir -p dist
	montage -font /System/Library/Fonts/Supplemental/Arial.ttf -label '%t' -pointsize 13 \
		build/app/generated/res/generateDebugIconPack/drawable-nodpi/*.png \
		-tile 10x -geometry 120x120+8+8 -background '#E5E7EB' dist/preview.png
	@echo "dist/preview.png"

clean:
	flutter clean
	rm -rf dist

# deploy, release, bump, store-check, store-meta, version
include store.mk
