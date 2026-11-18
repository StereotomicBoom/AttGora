#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
PROJECT="$PWD"
BUILD="$PROJECT/mac/build"
DEST="$HOME/Applications"
NAME="Todo"
BUNDLE_ID="se.gustavlundstrom.todo"
APP="$DEST/$NAME.app"
VERSION="$(tr -d '[:space:]' < "$PROJECT/VERSION")"
SHARE="$DEST/$NAME för Mac"
mkdir -p "$BUILD"

if [ "${1:-}" = "release" ]; then
  git -C "$PROJECT" diff --quiet HEAD || { echo "Committa ändringarna först."; exit 1; }
  if gh release view "v$VERSION" >/dev/null 2>&1; then echo "v$VERSION finns redan. Höj VERSION först."; exit 1; fi
fi

echo "Bygger appen (version $VERSION)…"
for arch in arm64 x86_64; do
  swiftc -O -parse-as-library -target "$arch-apple-macos14.0" -o "$BUILD/$NAME-$arch" "$PROJECT"/mac/Todo/*.swift
done
lipo -create -output "$BUILD/$NAME" "$BUILD/$NAME-arm64" "$BUILD/$NAME-x86_64"

if [ ! -f "$BUILD/AppIcon.icns" ] || [ ! -f "$BUILD/icon-square-1024.png" ] || [ "$PROJECT/mac/make-icon.swift" -nt "$BUILD/AppIcon.icns" ]; then
  echo "Ritar ikonen…"
  swiftc -O -o "$BUILD/make-icon" "$PROJECT/mac/make-icon.swift"
  "$BUILD/make-icon" 1024 "$BUILD/icon-1024.png" full
  "$BUILD/make-icon" 1024 "$BUILD/icon-square-1024.png" square
  ICONSET="$BUILD/AppIcon.iconset"
  rm -rf "$ICONSET" && mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z $size $size "$BUILD/icon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z $double $double "$BUILD/icon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$BUILD/AppIcon.icns"
fi

echo "Sätter ihop appen…"
STAGE="$BUILD/$NAME.app"
rm -rf "$STAGE"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"
cp "$BUILD/$NAME" "$STAGE/Contents/MacOS/$NAME"
cp "$BUILD/AppIcon.icns" "$STAGE/Contents/Resources/AppIcon.icns"
cat > "$STAGE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleDevelopmentRegion</key><string>sv</string>
  <key>CFBundleLocalizations</key><array><string>sv</string></array>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
codesign --force --deep --sign - "$STAGE" >/dev/null 2>&1

if pgrep -x "$NAME" >/dev/null; then
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || pkill -x "$NAME" || true
  sleep 1
fi
mkdir -p "$DEST"
if [ -d "$APP" ]; then rm -rf "$APP"; fi
cp -R "$STAGE" "$APP"
touch "$APP"

if [ ! -x "$BUILD/set-icon" ] || [ "$PROJECT/mac/set-icon.swift" -nt "$BUILD/set-icon" ]; then swiftc -O -o "$BUILD/set-icon" "$PROJECT/mac/set-icon.swift"; fi
"$BUILD/set-icon" "$BUILD/icon-square-1024.png" "$APP" || echo "(kunde inte sätta den fyrkantiga ikonen)"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" >/dev/null 2>&1 || true

LINK="$HOME/Desktop/$NAME.app"
if [ -L "$LINK" ]; then rm "$LINK"; fi
if [ ! -e "$LINK" ]; then ln -s "$APP" "$LINK"; fi

echo "Packar delningspaketet…"
rm -rf "$SHARE" "$SHARE.zip"
mkdir -p "$SHARE"
cp -R "$STAGE" "$SHARE/$NAME.app"
cp "$PROJECT/delning/Så installerar du (Mac).txt" "$SHARE/Så installerar du.txt"
(cd "$DEST" && ditto -c -k --sequesterRsrc --keepParent "$NAME för Mac" "$NAME för Mac.zip")

echo "Klart: $APP (genväg på skrivbordet, källkod i $PROJECT, delningspaket $SHARE.zip)"

if [ "${1:-}" = "release" ]; then
  RELEASE_ZIP="$BUILD/Todo-$VERSION-mac.zip"
  cp "$SHARE.zip" "$RELEASE_ZIP"
  git -C "$PROJECT" push origin HEAD
  gh release create "v$VERSION" "$RELEASE_ZIP" --title "Todo $VERSION" --notes "Ladda ner Todo-$VERSION-mac.zip, packa upp och dra Todo.app till Program. Läs \"Så installerar du.txt\" första gången."
  echo "Släppt: v$VERSION"
fi
