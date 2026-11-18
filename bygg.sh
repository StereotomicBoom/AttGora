#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
PROJECT="$PWD"
BUILD="$PROJECT/mac/build"
DEST="$HOME/Applications"
NAME="AttGöra"
EXEC="AttGora"
OLD_NAME="Todo"
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
command -v npm >/dev/null || { echo "Node.js saknas. Installera det från https://nodejs.org och kör igen."; exit 1; }
[ -d "$PROJECT/node_modules" ] || (cd "$PROJECT" && npm install --no-audit --no-fund)
(cd "$PROJECT" && npm run -s build)
for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos14.0" -o "$BUILD/$EXEC-$arch" "$PROJECT/mac/src/main.swift" -framework Cocoa -framework WebKit
done
lipo -create -output "$BUILD/$EXEC" "$BUILD/$EXEC-arm64" "$BUILD/$EXEC-x86_64"

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
cp "$BUILD/$EXEC" "$STAGE/Contents/MacOS/$EXEC"
cp "$BUILD/AppIcon.icns" "$STAGE/Contents/Resources/AppIcon.icns"
cp -R "$BUILD/web" "$STAGE/Contents/Resources/web"
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
  <key>CFBundleExecutable</key><string>$EXEC</string>
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

if pgrep -x "$EXEC" >/dev/null || pgrep -x "$OLD_NAME" >/dev/null; then
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || pkill -x "$EXEC" || pkill -x "$OLD_NAME" || true
  sleep 1
fi
rm -rf "$DEST/$OLD_NAME.app" "$DEST/$OLD_NAME för Mac" "$DEST/$OLD_NAME för Mac.zip"
if [ -L "$HOME/Desktop/$OLD_NAME.app" ]; then rm "$HOME/Desktop/$OLD_NAME.app"; fi
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
  RELEASE_ZIP="$BUILD/$EXEC-$VERSION-mac.zip"
  cp "$SHARE.zip" "$RELEASE_ZIP"
  git -C "$PROJECT" push origin HEAD
  gh release create "v$VERSION" "$RELEASE_ZIP" --title "$NAME $VERSION" --notes "Ladda ner $EXEC-$VERSION-mac.zip, packa upp och dra $NAME.app till Program. Läs \"Så installerar du.txt\" första gången."
  echo "Släppt: v$VERSION"
fi
