#!/bin/bash
# Builds "build/Downloads Organizer.app". Only ever deletes this project's own build output.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Downloads Organizer.app"
ICONSET="build/AppIcon.iconset"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/DownloadsOrganizer"

rm -rf "$APP" "$ICONSET"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DownloadsOrganizer"

"$BIN" --make-iconset "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Downloads Organizer</string>
    <key>CFBundleDisplayName</key><string>Downloads Organizer</string>
    <key>CFBundleIdentifier</key><string>com.laylachen.downloadsorganizer</string>
    <key>CFBundleExecutable</key><string>DownloadsOrganizer</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSDownloadsFolderUsageDescription</key><string>Downloads Organizer looks in your Downloads folder so it can sort your files into cute folders.</string>
    <key>NSDesktopFolderUsageDescription</key><string>Downloads Organizer puts your sorted folders on the Desktop and gives them cute icons.</string>
    <key>NSDocumentsFolderUsageDescription</key><string>Downloads Organizer can sort into or clean up folders you choose.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "✨ Built $APP"

# Put a copy on the Desktop. Only ever replaces an older copy of THIS app (checked by bundle id).
DEST="$HOME/Desktop/Downloads Organizer.app"
if [ -e "$DEST" ]; then
    if [ "$(defaults read "$DEST/Contents/Info" CFBundleIdentifier 2>/dev/null)" != "com.laylachen.downloadsorganizer" ]; then
        echo "Something else is already at $DEST, so it was left alone."
        exit 0
    fi
    rm -rf "$DEST"
fi
ditto "$APP" "$DEST"
touch "$DEST"   # nudges Finder to show the new icon
echo "🖥️  Installed on your Desktop"
