# Android (love-android 11.5a)

`mobile/android/` is a **vendored copy** of
[love2d/love-android](https://github.com/love2d/love-android) at tag
**11.5a** (matches `conf.lua` `t.version = "11.5"`), tracked directly in
this repo,  no git submodules involved. Nested `love` sources live at
`mobile/android/love/src/jni/love` (also vendored). Build outputs
(`app/build/`, `love/build/`, `.gradle/`, `local.properties`) stay
gitignored.

## Refreshing the vendored tree

To pick up a newer love-android release, replace the tree and re-vendor:

```bash
rm -rf mobile/android
git clone --depth 1 --branch <new-tag> --recurse-submodules --shallow-submodules \
  https://github.com/love2d/love-android.git mobile/android
rm -rf mobile/android/.git mobile/android/love/src/jni/love/.git \
       mobile/android/.gitmodules
```

`scripts/build_android.sh` re-applies project branding on every run
(`gradle.properties` app id / name / portrait, plus permission trims), so a
refresh is safe,  just rebuild.

## Build

```bash
# Build the APK
scripts/build_android.sh

# Build the APK, setting app.version_name/app.version_code to match a release
scripts/build_android.sh --version 0.2.5

# Zip game.love + branding only (no Android SDK required)
scripts/build_android.sh --package-only
```

Or via `scripts/build.sh android [--version X.Y.Z]`.

The embedded `game.love` deliberately excludes `data/generated/`,
`assets/generated/`, and any ROM. It contains the first-boot Lua importer and
`tools/rom_manifest.json`.

ROM / mod / save import on Android uses `love.system.pickFile([kind])` →
`GameActivity.showFilePicker` (Storage Access Framework), which copies the
chosen file under the app save directory as `picked_rom.gb`,
`picked_mod.zip`, or `picked_save.sav`. `RomImporter` imports pending files
from that folder on Choose / refocus; see `docs/launcher.md`. The APK payload
itself remains data-free (no embedded ROM or generated cache).

### Autoboot

The imported cart is **kept** in the save directory, and its presence is what
makes the next launch skip the launcher and go straight into that game
(`RomImporter.autobootVersion`, called from `main.lua`). The launcher is a
first-run / re-provisioning screen on a phone, not a per-launch gate.

- **First run** — no `.gb` in the save directory, so the launcher comes up to
  import a ROM and set up mods.
- **Provisioned** — `picked_rom.gb` (or any save-dir `.gb`) is routed by SHA-1
  and that game boots directly, with whatever mods were left enabled; the mod
  loader restores enable state from the persisted options on every boot, so
  autoboot needs no special handling for them.
- **Back to the launcher** — delete the `.gb`. That is also the way back to the
  MODS tab, the save-slot picker, and ROM re-import.
- **Stale cache** — ROM present but its extracted data missing or from an older
  cache format (e.g. after an app update): the launcher runs, picks that same
  ROM up automatically, shows extraction progress, and one Play tap resumes
  normal autoboot afterwards.

Both games imported: the marker is whichever ROM file is on disk, with
`picked_rom.gb` preferred, so the last cart picked is the one that autoboots.

Desktop is unaffected — the launcher's ROM columns and Play button are the
point there. `POKEPORT_AUTOBOOT=1 love .` forces the autoboot path on for
desktop testing, the way `POKEPORT_TOUCH=1` exercises the mobile controls.

### Quitting must end the process

`love.run` in `main.lua` calls `os.exit` on a real (non-`"restart"`) quit when
`love.system.getOS() == "Android"`. **Do not remove it.** Ending the SDL thread
finishes the activity but leaves the process warm, and liblove only releases
PhysFS in the filesystem module's destructor, which that path never runs
(`love/src/jni/love/src/modules/filesystem/physfs/Filesystem.cpp`). Android
then gives the next launch the same process:

```
ActivityTaskManager: The Process com.theboisclub.pokemonred Already Exists in BG. So sending its PID: 10056
SDL/APP: [LOVE] Error: [love "boot.lua"]:48: Failed to initialize filesystem: already initialized
```

The app appears to launch and instantly die, and only starts again after being
swiped out of Recents. Autoboot makes launch → play → exit → relaunch the
everyday loop, so this is hit constantly without the hard exit.

`"restart"` quits (mod toggle, importer hand-off) deliberately re-enter boot
inside the running process and are excluded — liblove tears the Lua state, and
so the filesystem module, down for those.

### SDK / NDK

love-android 11.5a expects:

- **JDK 17**
- Android SDK with **API 34**
- NDK **25.2.9519653** (Apple Silicon host supported)

Set `ANDROID_SDK_ROOT` (or `ANDROID_HOME`), or let the script write
`local.properties` when it finds `~/Library/Android/sdk`.

Gradle flavor used: **`embedNoRecord`** (game fused into the APK, no microphone).
Build task: `assembleEmbedNoRecordDebug`.

The APK lands under `app/build/outputs/apk/embedNoRecord/debug/`.
`scripts/build_android.sh` also copies it to `dist/android/debug/`.

### Payload path

`app/src/embed/assets/game.love` - zip of `main.lua`, `conf.lua`, `src/`,
`data/`, `assets/`, and `tools/rom_manifest.json`. Generated game data,
scripts, tests, and mobile build sources are excluded.

## Branding (applied by the build script)

| Setting | Value |
| --- | --- |
| `app.application_id` | `com.theboisclub.pokemonred` |
| `app.name` | Pokemon Red |
| `app.orientation` | `portrait` |
| `app.version_name` / `app.version_code` | set from `--version X.Y.Z` (code = major*10000 + minor*100 + patch); left as-is if `--version` is omitted |
| Permissions | INTERNET / RECORD_AUDIO / WRITE_EXTERNAL_STORAGE stripped; VIBRATE + BLUETOOTH kept |

## Releases

`.github/workflows/release.yml` builds the APK with `--version` set to the
release version and publishes it alongside the macOS/Windows/Linux builds as
`PokemonRed-<version>-android.apk`.

## Signing

Signed with the default Android keystore (no setup required).
