# Attacca

*attacca* (It.): go straight into the next movement without a pause.

Minimal iOS 17+ SwiftUI app: pick a folder in iCloud Drive, browse its subfolders,
and play every audio file in a folder one after another, sorted by file name.

## Features
- Folder picker (persists across launches via a security-scoped bookmark)
- Folder tree browsing, audio files listed per folder
- Sequential playback in name order (Finder-style: "Track 2" before "Track 10")
- **Gapless** transitions between tracks (true *attacca*), via SFBAudioEngine
- Formats: **Opus**, Ogg Vorbis, FLAC, MP3, AAC/M4A, ALAC, WAV, AIFF, CAF, WavPack, Monkey's Audio, Musepack, and more.
  Only files the engine can decode are listed.
- Downloads iCloud placeholders on demand; prefetches the next 2 tracks
- "Download all" button per folder (cloud icon, top right)
- Background playback, lock-screen / Control Center controls, scrubbing
- Handles calls and other audio interruptions
- No iCloud entitlement or Google/Dropbox API keys needed

## Build (GitHub Actions only)

No Mac or local Xcode needed. Every push to `main` (or **Actions → Build unsigned IPA → Run workflow**)
builds an unsigned `Attacca.ipa` on a GitHub-hosted macOS runner via `.github/workflows/build.yml`:

1. `xcodegen generate` creates `Attacca.xcodeproj` from `project.yml`
2. `xcodebuild` builds for iOS with code signing disabled
3. `Attacca.app` is packaged as `Payload/Attacca.app` → `Attacca.ipa`
4. The IPA is uploaded as the run artifact **`Attacca-ipa`** (kept 30 days)

## Install (SideStore)

SideStore signs the IPA on the iPhone with your Apple ID.

1. One-time: install SideStore via iloader (computer + USB), install **LocalDevVPN**,
   enable **Settings → Privacy & Security → Developer Mode**.
2. Download **`Attacca-ipa`** from the run page in Safari; tap the zip in Files to extract `Attacca.ipa`.
3. Connect LocalDevVPN → **SideStore → My Apps → +** → pick `Attacca.ipa`.
4. Every 7 days: LocalDevVPN → SideStore → **Refresh All**.

Bundle ID: `com.jagmsingh.attacca` (SideStore appends your team ID when signing).

## Use
1. Put music in a folder in iCloud Drive (from a Mac, iCloud.com, or the Files app).
2. Launch, tap **Choose Folder**, select that folder.
3. Tap a track to play from there, or **Play All**.

## Offline
- Tracks played or downloaded stay on the device, but iOS can evict them when storage is low.
- For guaranteed offline use: in the **Files** app, long-press the music folder > **Keep Downloaded**.

## Files
| File | Role |
|---|---|
| `AttaccaApp.swift` | App entry, injects shared state |
| `FolderAccess.swift` | Picked root folder + persistent bookmark |
| `Library.swift` | Lists folders/audio files, sorting, placeholder names |
| `CloudFile.swift` | iCloud download status, on-demand download with timeout |
| `Player.swift` | SFBAudioEngine `AudioPlayer`: gapless queue, auto-advance, Now Playing, remote commands |
| `Views.swift` | Root, folder list, track rows, mini player |

## Notes
- Audio engine: [SFBAudioEngine](https://github.com/sbooth/SFBAudioEngine) 0.14.0 (MIT), pinned in `project.yml`.
  Some bundled codecs are LGPL and are linked statically here, which is fine for personal use;
  redistributing the built app would require dynamic linking.
- First build takes longer (~10–15 min) while Swift Package Manager fetches and compiles the codecs.
- Also works with other Files providers (Dropbox, OneDrive) if their apps are installed, though their offline behavior is less predictable.
- For strict byte-order sorting instead of Finder-style, replace `localizedStandardCompare` with `<` in `Library.swift`.

---
(c) 2026 jag.m.singh@gmail.com
