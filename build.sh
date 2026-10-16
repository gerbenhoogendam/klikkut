#!/bin/zsh
# Bouwt Muisklikkert.app (Apple silicon) in ./build.
# Gebruik `./build.sh --install` om hem naar /Applications te kopiëren.
# Zet SIGN_IDENTITY (bijv. "Developer ID Application: Naam (TEAMID)") om te ondertekenen voor distributie;
# zonder SIGN_IDENTITY wordt ad-hoc ondertekend (alleen voor deze Mac).
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Muisklikkert.app"

SIGN_IDENTITY="${SIGN_IDENTITY:--}"

# De Command Line Tools missen de SwiftUI-macroplugin; gebruik Xcode als die er is.
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
    for xcode in /Applications/Xcode.app /Applications/Xcode-beta.app; do
        if [[ -d "$xcode" ]]; then
            export DEVELOPER_DIR="$xcode/Contents/Developer"
            break
        fi
    done
fi

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Muisklikkert"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Muisklikkert"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Muisklikkert</string>
    <key>CFBundleDisplayName</key>
    <string>Muisklikkert</string>
    <key>CFBundleIdentifier</key>
    <string>nl.gerben.Muisklikkert</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleExecutable</key>
    <string>Muisklikkert</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.2.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$APP"
else
    # Hardened runtime + timestamp zijn vereist voor notarisatie.
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi
echo "Gebouwd: $APP"

if [[ "${1:-}" == "--install" ]]; then
    # Netjes afsluiten zodat de laatste klikken worden opgeslagen.
    osascript -e 'quit app "Muisklikkert"' 2>/dev/null || pkill -x Muisklikkert 2>/dev/null || true
    sleep 1
    rm -rf /Applications/Muisklikkert.app
    cp -R "$APP" /Applications/
    echo "Geïnstalleerd in /Applications/Muisklikkert.app"
fi
