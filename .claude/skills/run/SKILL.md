---
name: run
description: Build, install, launch, and screenshot the Manga Shark iOS app in the simulator. Use when asked to run the app, test new functionality, or verify a UI change works.
---

# Running Manga Shark

Manga Shark is a SwiftUI app with no test target — verification means
building it, installing it on a simulator, launching it, and looking at
a screenshot.

The app talks to a self-hosted Suwayomi instance over Tailscale
(`AppConfig.suwayomiBaseURL`, currently
`http://franciss-mac-mini.wampus-boa.ts.net:4567`). The machine running
this skill must be on the same Tailnet for the Library view (and anything
else that hits Suwayomi) to load real data instead of showing the error
state.

## 1. Pick/boot a simulator

```bash
xcrun simctl list devices available | grep "iPhone 17"
```

Boot it if it's `(Shutdown)`:

```bash
xcrun simctl boot "<UDID>"
```

## 2. Build for that simulator

```bash
cd /Users/franciscasao/Developer/manga-shark
xcodebuild -project manga-shark.xcodeproj -scheme manga-shark \
  -destination 'id=<UDID>' build 2>&1 | tail -15
```

Expect `** BUILD SUCCEEDED **`. First build resolves SPM packages
(Kingfisher, ZIPFoundation) and takes longer.

## 3. Install and launch

The bundle ID is `com.karlcasao.manga-shark`. Find the built `.app`
(DerivedData path includes a hash that can change, so locate it
dynamically rather than hardcoding):

```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 6 -path "*Debug-iphonesimulator/manga-shark.app" -print -quit)
xcrun simctl install "<UDID>" "$APP"
xcrun simctl launch "<UDID>" com.karlcasao.manga-shark
```

## 4. Screenshot and inspect

Give the app a couple seconds to fetch from Suwayomi, then capture:

```bash
sleep 4
xcrun simctl io "<UDID>" screenshot /tmp/manga-shark.png
```

Read `/tmp/manga-shark.png` with the Read tool to inspect it visually.

## What "working" looks like

- **Library view**: grid of manga cover thumbnails with titles below each,
  loaded over Tailscale. A `ProgressView` while loading is fine; a
  permanent spinner or a "Couldn't Load Library" error means Suwayomi
  wasn't reachable (check Tailscale connectivity) or the API/ATS config
  in `AppConfig.swift` / `Info.plist` is wrong.
- For new features, navigate/interact as needed (simulator supports
  `xcrun simctl ui` for some settings, but taps/swipes generally need
  `xcrun simctl` HID events via a tool like `idb`, or the Simulator app's
  own UI via AppleScript — fall back to that if a feature requires
  interaction beyond the initial screen).
