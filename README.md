# Attacca

*attacca* (It.): go straight into the next movement without a pause.

Minimal iOS 17+ SwiftUI app: pick a folder in iCloud Drive, browse its subfolders,
and play every audio file in a folder one after another, sorted by file name.

## Features
- One-time **setup screen** explaining the iCloud Drive grant (an Apple privacy requirement), with steps;
  the choice is validated, so picking a sub-folder by mistake triggers an explanation and a retry
- The grant persists via a security-scoped bookmark; all browsing is then in-app
- Reopens in the **last folder viewed**
- Clickable **breadcrumb** at the top (`iCloud Drive : Music : Bach`): tap any level to jump there
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
4. The IPA is uploaded as the run artifact **`Attacca-ipa`** (kept 30 days) and published as a **GitHub Release** (`build-N`, marked Latest)

## Releases & versions

- Push to `main` → **dev build**, published as a pre-release `build-N`.
- Push a tag `vX.Y.Z` → **versioned release** `Attacca X.Y.Z`, marked **Latest**.
  The app's version is taken from the tag; the build number is the Actions run number.
- The phone link `…/releases/latest/download/Attacca.ipa` always gives the newest **versioned** release.
- Version shown in the app: ⚙︎ → bottom of the screen.

```bash
git tag v1.0.0 && git push origin v1.0.0     # cut a release
```

## Install (SideStore)

SideStore signs the IPA on the iPhone with your Apple ID.

1. One-time: install SideStore via iloader (computer + USB), install **LocalDevVPN**,
   enable **Settings → Privacy & Security → Developer Mode**.
2. In iPhone Safari open `https://github.com/<owner>/Attacca/releases/latest/download/Attacca.ipa` → **Download** (lands in Files → Downloads).
3. Connect LocalDevVPN → **SideStore → My Apps → +** → pick `Attacca.ipa`.
4. Every 7 days: LocalDevVPN → SideStore → **Refresh All**.

Bundle ID: `com.jagmsingh.attacca` (SideStore appends your team ID when signing).

## Use
1. Put music in a folder in iCloud Drive (from a Mac, iCloud.com, or the Files app).
2. First launch: tap **Choose iCloud Drive**, then in the picker tap **iCloud Drive** → **Open** (one time only).
3. Tap a track to play from there, or **Play All**.

## Offline
- Tracks played or downloaded stay on the device, but iOS can evict them when storage is low.
- For guaranteed offline use: in the **Files** app, long-press the music folder > **Keep Downloaded**.

## Files
| File | Role |
|---|---|
| `AttaccaApp.swift` | App entry, injects shared state |
| `FolderAccess.swift` | Granted root + bookmark, navigation path persisted across launches |
| `Library.swift` | Lists folders/audio files, sorting, placeholder names |
| `CloudFile.swift` | iCloud download status, on-demand download with timeout |
| `Player.swift` | SFBAudioEngine `AudioPlayer`: gapless queue, auto-advance, Now Playing, remote commands |
| `Views.swift` | Root, breadcrumb bar, folder list, track rows, mini player |
| `Setup.swift` | One-time setup screen and validated iCloud Drive picker |
| `Assets.xcassets/AppIcon` | App icon (single 1024×1024, iOS generates the rest) |
| `design/make_icon.py` | Regenerates the icon: `python3 design/make_icon.py AppIcon.png` (needs Pillow + NumPy) |

## Notes
- Audio engine: [SFBAudioEngine](https://github.com/sbooth/SFBAudioEngine) 0.14.0 (MIT), pinned in `project.yml`.
  Some bundled codecs are LGPL and are linked statically here, which is fine for personal use;
  redistributing the app would require dynamic linking.
- First build takes longer (~10–15 min) while Swift Package Manager fetches and compiles the codecs.
- For strict byte-order sorting instead of Finder-style, replace `localizedStandardCompare` with `<` in `Library.swift`.

---
(c) 2026 jag.m.singh@gmail.com
