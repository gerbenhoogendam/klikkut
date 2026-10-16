#!/bin/zsh
# Bouwt, ondertekent en notariseert Muisklikkert en maakt build/Muisklikkert.zip voor een GitHub-release.
#
# Eenmalig nodig:
#   1. Een "Developer ID Application"-certificaat in je sleutelhanger (Xcode → Instellingen → Accounts → Beheer certificaten).
#   2. Notarisatiegegevens in de sleutelhanger:
#        xcrun notarytool store-credentials klikkut --apple-id <jouw Apple ID> --team-id <TEAMID>
#
# Gebruik: SIGN_IDENTITY="Developer ID Application: Naam (TEAMID)" ./release.sh
set -euo pipefail
cd "$(dirname "$0")"

: "${SIGN_IDENTITY:?Zet SIGN_IDENTITY op je Developer ID Application-identiteit}"
NOTARY_PROFILE="${NOTARY_PROFILE:-klikkut}"
APP="build/Muisklikkert.app"
ZIP="build/Muisklikkert.zip"

SIGN_IDENTITY="$SIGN_IDENTITY" ./build.sh
codesign --verify --strict --verbose=2 "$APP"

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

xcrun stapler staple "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
spctl --assess --type execute --verbose "$APP"
echo "Klaar: $ZIP is ondertekend, genotariseerd en gestapled."
