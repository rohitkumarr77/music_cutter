<<<<<<< HEAD
# 🎵 Music Cutter — Parody Maker

> A full-featured Flutter app to **cut, trim, merge and manage multiple audio files** into a single parody track. Built for Android with persistent internal storage, haptic feedback, and a polished dark UI.

---

## 📱 Screenshots Overview

| Screen         | Description                                             |
|----------------|---------------------------------------------------------|
| **Home**       | Project list with search, sort, multi-select, stats bar |
| **Editor**     | Add songs, trim, reorder, merge into one file           |
| **Trim Sheet** | Visual waveform, start/end sliders, live preview        |
| **Outputs**    | Play exported files with seek bar, delete               |


# Music Cutter App

## Screenshots

### Home Screen
![Home Screen](screenshot/home_page.jpeg)

### Editor Screen
![Editor Screen](screenshot/editing_page.jpeg)


### Output Screen
![Output Screen](screenshot/output.jpeg)

---

## ✨ Features

### 🏠 Home Screen
- **Project list** with gradient cards unique per project
- **Search bar** — filter projects by name in real time
- **Sort menu** — sort by Recent · Oldest · Name · Most Songs · Longest
- **Stats bar** — total projects, songs, duration, merged count
- **Multi-select mode** — long press to enter, select multiple, delete all at once
- **Duplicate project** — copies all songs and trim settings
- **Rename project** — inline dialog with auto-capitalize
- **Time ago label** — shows "5m ago", "2d ago" on each card
- **Haptic feedback** — every tap, long press, create, delete has the right vibration

### ✂️ Editor Screen
- **Add multiple songs at once** — system file picker with multi-select
- **Songs copied to internal storage** — with unique timestamp filenames to prevent collisions
- **Drag to reorder** — hold and drag any song to change position
- **Merge All button** — appears when 2+ songs added, combines all into one MP3
- **Merged file card** — shows result at top with play/re-merge buttons
- **Mini player with seek bar** — drag to any position, ⏪ ⏩ skip 10s buttons
- **Auto-save** — saves after every action (add, remove, trim, volume, reorder, merge)
- **Background save** — saves automatically when app goes to background
- **Restore on reopen** — all songs, trim points, and merged file restored after restart

### 🎵 Song Tile (Advanced)
- **Animated equalizer bars** — 4-bar animation when playing
- **Glow effect** — purple border glow on the active song
- **PLAYING badge** — label next to song name when active
- **Trim progress bar** — visual bar showing exactly which portion is selected
- **Volume control** with slider + preset buttons (Mute / 50% / 100% / 150%)
- **Volume label** — shows Muted / Low / Normal / Boosted
- **Song info panel** — Full Duration, Trimmed Duration, Start/End points
- **⋮ More menu** — Edit Trim · Rename · Duplicate · Remove
- **Long press to rename** — directly on the song name
- **Confirm before delete** — dialog before removing any song

### ✂️ Trim Sheet
- **Visual waveform** — shows full audio with highlighted trim range
- **Start & End sliders** — drag to set exact trim points
- **Live preview** — tap Preview to hear exactly what will be exported
- **Auto-stop** — preview stops at the end trim point automatically
- **Info bar** — shows Start, Duration, End in real time
- **Safe clamping** — sliders never overlap or go out of range

### 🎧 Outputs Screen
- **List of all exported MP3 files** — sorted by newest first
- **Now Playing card** — appears when a file is playing
- **Seek bar** — drag to any position in the file
- **⏪ ⏩ skip 10 seconds** — quick navigation buttons
- **Storage usage** — shows total app storage used
- **Delete files** — with confirmation dialog

### 📳 Haptic Feedback
Every interaction has the right physical feel:

| Action                 | Haptic                 |
|------------------------|------------------------|
| Light tap, chip, icon  | Light impact           |
| Play / Pause / Toggle  | Light impact           |
| Expand / Collapse tile | Selection click        |
| Volume preset tap      | Selection click        |
| Seek slider            | Selection click        |
| Trim applied           | Medium → Light         |
| Song added             | Light → Light          |
| Song removed           | Heavy                  |
| Duplicate              | Medium                 |
| Rename                 | Light                  |
| Merge complete         | Light → Medium → Heavy |
| Merge failed           | Heavy → Heavy          |
| Project created        | Light → Medium         |
| Project deleted        | Heavy                  |
| Long press             | Medium                 |
| Multi-select           | Selection click        |

---

## 🏗️ Project Structure

```
music_cutter_app/
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml        ← All permissions declared
├── lib/
│   ├── main.dart                      ← App entry, dark theme, portrait lock
│   │
│   ├── models/
│   │   └── song_model.dart            ← SongModel + Project data classes
│   │
│   ├── services/
│   │   ├── audio_service.dart         ← Playback + native trim + byte-merge
│   │   ├── storage_service.dart       ← SharedPreferences + file I/O
│   │   ├── permission_service.dart    ← Android audio permissions
│   │   └── haptic_service.dart        ← Centralized haptic feedback
│   │
│   ├── screens/
│   │   ├── home_screen.dart           ← Project list, search, sort, multi-select
│   │   ├── editor_screen.dart         ← Main editor, add/merge/play songs
│   │   └── outputs_screen.dart        ← Exported files, seek bar player
│   │
│   └── widgets/
│       ├── song_card.dart             ← Advanced song tile with all controls
│       └── trim_sheet.dart            ← Bottom sheet trim editor
│
├── pubspec.yaml                       ← Dependencies
└── README.md                          ← This file
```

---

## 🔐 Android Permissions

Declared in `AndroidManifest.xml`:

| Permission               | API Level             | Purpose                                        |
|--------------------------|-----------------------|------------------------------------------------|
| `READ_MEDIA_AUDIO`       | Android 13+ (API 33+) | Access audio files — new granular permission   |
| `READ_EXTERNAL_STORAGE`  | Android 12 and below  | Access audio on older devices                  |
| `WRITE_EXTERNAL_STORAGE` | Android 9 and below   | Write files on very old devices                |
| `FOREGROUND_SERVICE`     | All versions          | Keep audio processing alive in background      |
| `WAKE_LOCK`              | All versions          | Prevent CPU sleep during long merge operations |
| `INTERNET`               | All versions          | Reserved for future features                   |

Permissions are requested at runtime via `permission_handler` on first use.

---

## 📦 Dependencies

| Package                | Version | Purpose                                              |
|------------------------|---------|------------------------------------------------------|
| `audioplayers`         | ^5.2.1  | Audio playback, position tracking, seek              |
| `native_audio_trimmer` | ^1.0.0  | Trim audio natively — **no FFmpeg, no Maven issues** |
| `file_picker`          | ^8.0.3  | System audio file picker with multi-select           |
| `path_provider`        | ^2.1.2  | App documents and temp directories                   |
| `permission_handler`   | ^11.3.0 | Runtime Android permissions                          |
| `shared_preferences`   | ^2.2.2  | Persist projects as JSON across restarts             |
| `uuid`                 | ^4.3.3  | Unique IDs for projects and songs                    |
| `cupertino_icons`      | ^1.0.6  | iOS style icons                                      |

> **Why `native_audio_trimmer` instead of FFmpeg?**
> FFmpeg for Flutter (`ffmpeg_kit_flutter`) was archived in June 2025 and its Android `.aar` binary was removed from Maven Central — causing build failures for all users. `native_audio_trimmer` uses Android's built-in `MediaExtractor`, `MediaCodec`, and `MediaMuxer` APIs — **zero external downloads, instant build**.

---

## 💾 Data Persistence

All data survives app restarts:

### Projects & Songs — `SharedPreferences`
```
Key: "mc_projects_v1"
Value: JSON array of all projects
```

Each project stores:
- `id`, `name`, `createdAt`, `updatedAt`, `mergedPath`
- Array of songs with `filePath`, `startTrimMs`, `endTrimMs`, `volume`, `order`

## Audio Files — Internal Storage
```
Documents/
├── projects/
│   └── <project-id>/
│       ├── song1_1712345678.mp3    ← copied with timestamp (no collisions)
│       └── song2_1712345999.mp3
└── output/
    └── my_parody.mp3               ← exported merged file
```

## Auto-Save Triggers
The project saves automatically after every action:
- ✅ Song added (after each file)
- ✅ Song removed
- ✅ Trim points changed
- ✅ Volume changed
- ✅ Songs reordered
- ✅ Song renamed or duplicated
- ✅ Merge completed (saves output path)
- ✅ Back button pressed
- ✅ App goes to background (`WidgetsBindingObserver`)

### File Validation
On every project open, `validate()` checks each song's file path still exists on disk. Missing files are silently removed instead of crashing.

---

## 🔄 How Merge Works

```
Song 1: [==trim==]          → seg_0_timestamp.mp3
Song 2:       [==trim==]    → seg_1_timestamp.mp3
Song 3:   [====trim====]    → seg_2_timestamp.mp3
                                        ↓
                              Concat bytes into
                              output/parody.mp3
```

1. Each song is **trimmed** using `NativeAudioTrimmer.trim()` into a temp file
2. All temp files are **concatenated** byte-by-byte into the output file
3. Temp files are **deleted** after merge
4. Output path is **saved** to the project so the merged card reappears on restart

> **Note:** Byte concatenation works well for MP3 files. For best results use songs of the same format (all MP3 or all M4A).

---

## 🚀 Setup & Run

### Prerequisites
- Flutter SDK `>=3.0.0`
- Android Studio or VS Code
- Android device or emulator (API 21+)

### Steps

**1. Create a new Flutter project**
```bash
flutter create music_cutter_app
cd music_cutter_app
```

**2. Replace files**

Copy from this package into your project:
```
lib/                    → replace entire lib/ folder
android/app/src/main/AndroidManifest.xml
pubspec.yaml
```

**3. Install dependencies**
```bash
flutter clean
flutter pub get
```

**4. Run in debug mode**
```bash
flutter run
```

**5. Run in release mode** *(removes debug overlay boxes)*
```bash
flutter run --release
```

**6. Build APK**
```bash
flutter build apk --release
# APK at: build/app/outputs/flutter-apk/app-release.apk
```

---

## 🐛 Troubleshooting

### Debug boxes / colored overlay on screen
Those are Flutter's debug paint bounds — only appear in debug mode.
```bash
flutter run --release    # removes all debug overlays
```
Or on your phone: **Settings → Developer Options → Show layout bounds → OFF**

### Build failed: `com.arthenica:ffmpeg-kit-audio` not found
This happens if you have the old FFmpeg package. This project uses `native_audio_trimmer` which has no Maven dependency.
```bash
flutter clean
flutter pub get
```
Make sure `pubspec.yaml` has `native_audio_trimmer: ^1.0.0` and **no** `ffmpeg_kit_flutter` entry.

### Permission denied — can't pick audio files
Go to: **Phone Settings → Apps → Music Cutter → Permissions → Files and Media → Allow**

Or in the app tap "Open Settings" in the permission dialog.

### Data lost after reinstall
Reinstalling the app clears internal storage — this is Android's security model. The songs physically stored in `Documents/projects/` are deleted. SharedPreferences is also cleared. This is expected behavior.

### Merge produces no output
- Check all song files still exist (use the validate feature)
- Make sure trim end is greater than trim start
- Try with MP3 files for best compatibility

---

## 🎨 Design System

| Token      | Value              | Usage                        |
|------------|--------------------|------------------------------|
| Background | `#0D0D1A`          | App background               |
| Surface    | `#15152A`          | AppBar, mini player          |
| Card       | `#1C1C30`          | Song tiles, project cards    |
| Card 2     | `#252545`          | Input fields                 |
| Purple     | `#6C63FF`          | Primary accent, play buttons |
| Pink       | `#FF6584`          | Merge button, merged card    |
| Green      | `#2E7D32`          | Success snackbar             |
| Red        | `Colors.redAccent` | Delete actions               |

All animations use `250ms` duration with `Curves.easeInOut`.

---

## 📋 File Reference

| File                      | Lines | Responsibility                                        |
|---------------------------|-------|-------------------------------------------------------|
| `main.dart`               | 41    | Entry point, theme, orientation lock                  |
| `song_model.dart`         | 109   | `SongModel` + `Project` with JSON serialization       |
| `storage_service.dart`    | 122   | Load/save projects, copy audio, list outputs          |
| `audio_service.dart`      | 97    | Play/pause/seek, trim, merge songs                    |
| `permission_service.dart` | 12    | Request `READ_MEDIA_AUDIO` or `READ_EXTERNAL_STORAGE` |
| `haptic_service.dart`     | 154   | 25+ named haptic methods for every interaction        |
| `home_screen.dart`        | 981   | Project list, search, sort, multi-select, stats       |
| `editor_screen.dart`      | 379   | Add songs, merge, playback, lifecycle save            |
| `outputs_screen.dart`     | 472   | Exported files player with seek bar                   |
| `song_card.dart`          | 852   | Advanced tile: trim bar, volume presets, animations   |
| `trim_sheet.dart`         | 149   | Bottom sheet waveform trim editor                     |

---

## 📄 License

This project is for personal and educational use.
Audio files remain the property of their respective copyright holders.
Do not distribute copyrighted audio without permission.

---

*Built with Flutter  — Music Cutter v1.0.0*
=======
# music_cutter
>>>>>>> 3a4ba1397d85fb52028ac5b1a4ce1c945378e467
