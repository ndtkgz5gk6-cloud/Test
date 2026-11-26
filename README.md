# Kalender – kalender med att göra-listor

Lägg till uppgifter på valfri dag i kalendern och bocka av dem när de är klara. Appen finns i två versioner med samma funktioner:

- **Webbversion** i `web/` som körs direkt i webbläsaren.
- **iOS-app** i `Kalender/` skriven i SwiftUI.

## Webbversionen

Hela appen ligger i en enda fil, `web/index.html`.

- **Kör lokalt:** öppna `web/index.html` i en webbläsare, eller starta en enkel server:
  ```sh
  cd web
  python3 -m http.server 8000
  ```
  och gå till http://localhost:8000.
- **Använd på iPhone:** lägg mappen `web/` på en webbserver, till exempel GitHub Pages. Öppna sidan i Safari och välj *Dela → Lägg till på hemskärmen*. Då får appen en egen ikon och öppnas i helskärm.
- **Kategorier med färger:** varje uppgift kan få en kategori. Från början finns Arbete, Privat, Hem och Hälsa.
  - Prickarna i kalendern och strecket vid varje uppgift visas i kategorins färg.
  - Filtrera på en kategori med knapparna ovanför kalendern.
  - Under *Hantera kategorier* skapar du nya kategorier och byter namn och färg. Om du raderar en kategori finns uppgifterna kvar, men utan kategori.
- **Listvy:** knappen *Lista* i toppen visar alla uppgifter i en lång lista med en rubrik för varje datum.
  - Överst ligger försenade uppgifter som inte är klara.
  - Listan visar 60 dagar framåt, och du kan visa fler eller tidigare dagar.
  - *Visa klara* döljer avbockade uppgifter, och kategorifiltret gäller även här.
  - Tryck på en datumrubrik för att öppna dagen i kalendern.
- **Data:** uppgifterna sparas i webbläsaren med `localStorage`. Under *Säkerhetskopia* kan du kopiera ut dem som text och läsa in dem igen.
- **Kortkommandon:** `←` och `→` byter månad och `N` skapar en ny uppgift.
- **Skillnad mot iOS-appen:** webbversionen skickar inga påminnelser.

### Göra om webbversionen till en iOS-app

1. **Capacitor:** paketerar `web/index.html` som en riktig iOS-app utan att du skriver om något. Kräver en Mac med Xcode:
   ```sh
   npm init -y && npm install @capacitor/core @capacitor/cli @capacitor/ios
   npx cap init Kalender se.dittnamn.kalender --web-dir web
   npx cap add ios && npx cap open ios
   ```
2. **SwiftUI-appen i `Kalender/`:** en inbyggd app med samma funktioner plus påminnelser. Ändringar du gör i webbversionen behöver då föras över dit.

## iOS-appen

### Funktioner

- **Månadskalender** med veckonummer, där veckan börjar på måndag.
- Bläddra mellan månader med pilarna eller genom att svepa åt vänster eller höger. **Idag** hoppar tillbaka till dagens datum.
- **En prick under dagar som har uppgifter.** Färgad prick betyder att det finns uppgifter kvar, grön prick att alla är klara.
- **Att göra-lista per dag** som visar till exempel "2 av 5 klara".
- Uppgifter har titel, anteckningar, valfritt klockslag och prioritet (låg, normal eller hög).
- **Återkommande uppgifter** som upprepas varje dag, på vardagar, varje vecka, varannan vecka, varje månad eller varje år. Du kan välja ett slutdatum.
  - Varje tillfälle bockas av för sig.
  - När du raderar kan du välja att ta bort bara den dagen, den dagen och alla kommande, eller hela serien.
  - Uppgifter som upprepas den 31:a hamnar på sista dagen i kortare månader.
- **Påminnelser** som notis vid vald tid. För återkommande uppgifter planeras de närmaste tillfällena och fylls på varje gång appen öppnas.
- Svep åt höger för att markera en uppgift som klar och åt vänster för att radera den. Tryck på en uppgift för att redigera den.
- Uppgifterna sparas lokalt på telefonen med SwiftData.
- Gränssnittet är på svenska och har stöd för mörkt läge och VoiceOver.

### Krav

- En Mac med **Xcode 16** eller senare.
- iOS 17 eller senare.

### Så kör du appen

1. Klona repot och öppna `Kalender/Kalender.xcodeproj` i Xcode.
2. Välj en simulator, till exempel iPhone 16, och tryck **⌘R**.

#### På din egen iPhone

1. Klicka på projektet **Kalender** i Xcode, välj målet **Kalender** och fliken **Signing & Capabilities**.
2. Välj ditt Apple-ID under **Team**. Ett gratis Apple-ID fungerar.
3. Ändra **Bundle Identifier** till något unikt, till exempel `se.dittnamn.Kalender`.
4. Anslut iPhonen, välj den som mål och tryck **⌘R**. Första gången kan du behöva godkänna utvecklaren på telefonen under *Inställningar → Allmänt → VPN och enhetshantering*.

### Filer

| Fil | Innehåll |
|---|---|
| `KalenderApp.swift` | Appens startpunkt och hantering av notiser |
| `TodoItem.swift` | Datamodellen för en uppgift |
| `ContentView.swift` | Huvudvyn med kalendern ovanför dagens lista |
| `MonthCalendarView.swift` | Månadsvyn |
| `DayTodoListView.swift` | Att göra-listan för vald dag |
| `TodoEditorView.swift` | Formulär för att skapa och redigera uppgifter |
| `ReminderScheduler.swift` | Schemaläggning av påminnelser |
| `CalendarHelpers.swift` | Hjälpfunktioner för datum och den svenska kalendern |
