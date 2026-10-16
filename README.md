# Klikkut

Een klein menubalk-appje voor macOS dat al je muisklikken telt, per dag.

- In de menubalk staat het aantal klikken van vandaag; om middernacht begint de teller opnieuw.
- Klik op het icoon voor de details: links/rechts/overige knoppen, de laatste 24 uur, een grafiek per uur, de afgelopen 7 dagen en je recorddag.
- Alleen aantallen per uur worden opgeslagen, geen posities of losse tijdstippen, in `~/Library/Application Support/Muisklikkert/clicks.json`.
- Er is geen toestemming voor Toegankelijkheid of Invoermonitoring nodig.

Vereist macOS 14 of nieuwer op een Mac met Apple silicon.

## Bouwen

Vereist Xcode (de Command Line Tools alleen zijn niet genoeg voor de SwiftUI-macro's).

```bash
./build.sh            # bouwt build/Muisklikkert.app (ad-hoc ondertekend)
./build.sh --install  # en kopieert hem naar /Applications
```

## Release (ondertekend en genotariseerd)

Eenmalig: een *Developer ID Application*-certificaat in je sleutelhanger en notarisatiegegevens opslaan met
`xcrun notarytool store-credentials klikkut --apple-id <Apple ID> --team-id <TEAMID>`.

```bash
SIGN_IDENTITY="Developer ID Application: Naam (TEAMID)" ./release.sh
```

Dat levert `build/Muisklikkert.zip` op, klaar om aan een GitHub-release te hangen.
