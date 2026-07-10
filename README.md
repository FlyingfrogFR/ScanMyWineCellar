# ScanMyWineCellar

An iOS app that turns photos of your wine racks into a structured wine cellar inventory — no need to photograph every bottle individually.

Take a few pictures covering your shelves, and the app identifies every readable bottle (name, producer, vintage, color, region, country, appellation, grape varieties, and how many bottles of each), lets you review and correct the results, then adds everything to a searchable cellar you can export as a spreadsheet (CSV).

## How it works

1. **Scan** — Photograph your racks with the camera or pick photos from your library (up to 12 per scan). Whole shelves with many bottles per photo are fine; that's the point.
2. **Identify** — The photos are sent in a single request to the Anthropic Messages API (`claude-opus-4-8`) with a JSON schema, so the response comes back as structured data: one entry per wine with a bottle count, deduplicated across overlapping photos.
3. **Review** — A review screen shows everything that was found. Fix any misread names or vintages, adjust counts, and uncheck mistakes before committing.
4. **Cellar** — Wines land in a searchable, filterable inventory (SwiftData, stored on-device). Swipe to "drink one", edit details, add wines manually, and export the whole cellar as CSV for Excel/Numbers/Google Sheets.

## Requirements

- Xcode 16 or later (the project uses Xcode 16's folder-synchronized project format)
- iOS 17.0+ device or simulator (a real device is needed for the camera; the photo-library path works in the simulator)
- An Anthropic API key from [console.anthropic.com](https://console.anthropic.com/) → API Keys

## Getting started

1. Open `ScanMyWineCellar.xcodeproj` in Xcode.
2. Select the `ScanMyWineCellar` target → Signing & Capabilities → choose your Team (personal team is fine for your own device).
3. Build and run on your iPhone.
4. In the app, open **Settings** (gear icon) and paste your Anthropic API key. It's stored only in the device Keychain.
5. Tap the **scan** button (viewfinder icon) and photograph your first rack.

## Cost

The app calls the API only when you run a scan. Input is billed at $5 per million tokens for `claude-opus-4-8`; a scan with a handful of shelf photos typically uses on the order of 10–20K input tokens and a few thousand output tokens — a few cents per scan. There is no cost while browsing your cellar.

## Scanning tips

- Shoot straight-on so labels are readable; avoid heavy glare.
- Cover each shelf once — overlapping photos are handled, but fewer overlaps give more accurate counts.
- Bottles stored neck-out can't be identified from the capsule alone unless the wine is recognizable; pull them slightly or photograph a representative label.

## Project layout

```
ScanMyWineCellar/
├── ScanMyWineCellarApp.swift      App entry point (SwiftData container)
├── Models/
│   ├── Wine.swift                 SwiftData model + WineColor enum
│   └── ScannedWine.swift          Transient scan result (review screen)
├── Services/
│   ├── WineScanService.swift      Anthropic Messages API client (vision + structured output)
│   └── APIKeyStore.swift          Keychain storage for the API key
├── Views/
│   ├── CellarView.swift           Main inventory: search, filters, totals, export
│   ├── ScanView.swift             Photo capture/selection + scan trigger
│   ├── ScanReviewView.swift       Review & correct scan results
│   ├── WineDetailView.swift       Edit a cellar wine, drink/remove bottles
│   ├── ManualAddView.swift        Add a wine by hand
│   ├── SettingsView.swift         API key entry
│   ├── CameraPicker.swift         UIImagePickerController wrapper
│   └── ShareSheet.swift           UIActivityViewController wrapper (CSV export)
└── Export/
    └── CSVExporter.swift          Cellar → CSV file
```

## Privacy

Photos are sent to the Anthropic API solely to identify the bottles and are not stored by the app. The cellar database lives entirely on your device. Your API key never leaves the Keychain except as the authentication header on API requests.
