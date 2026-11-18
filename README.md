# Tapperoni

An incremental tap game for Android, made with Godot 4.7 (GDScript). An exploration project.

## Setup (nothing installed system-wide)

- **Godot editor:** a single file, `~/Applications/godot/Godot_v4.7.2-stable_linux.x86_64`.
  Its settings live in `~/.config/godot`, `~/.local/share/godot`, `~/.cache/godot`. To remove
  it, delete those and the file.
- **VS Code:** the `godot-tools` extension (recommended in `.vscode/`). Autocomplete and error
  checking need the Godot editor open with this project (it serves GDScript's language server).
- **Android toolchain:** a Docker image (headless Godot + Android export templates, JDK 17,
  Android SDK, adb), defined in `docker/Dockerfile`. Build it once: `bin/phone build-image`.

## Running it

- **On the desktop:** open the project in the Godot editor and press F5 (or Run in VS Code).
- **On the phone** (Android 11+, same network as jupiter):
  1. Once: Settings → About phone → tap *Build number* 7 times. Then Developer options →
     **Wireless debugging** on → *Pair device with pairing code*, and run
     `bin/phone pair <ip:port> <code>` with the address and code shown there.
  2. Every time: `bin/phone deploy`. It exports a debug APK, installs it and launches it.
     If the phone isn't found, pass the *IP address & Port* from the Wireless debugging screen:
     `bin/phone deploy 192.168.0.42:37123`.
  3. `bin/phone logs` follows the game's `print()` output and errors from the phone.

`bin/phone check` loads the project headless and reports script errors.

## Layout

| Path | What |
|---|---|
| `scripts/game.gd` | Autoload `Game`: state, economy, upgrades (data in `UPGRADES`), saving, offline progress, number formatting |
| `scripts/main.gd`, `scenes/main.tscn` | The main screen |
| `export_presets.cfg` | Android export preset (package `io.github.dukeofetiquette.tapperoni`, arm64) |
| `bin/phone` | Export / install / logs, via the Docker toolchain |

The save file is `user://save.json` (on desktop: `~/.local/share/godot/app_userdata/Tapperoni/`).
It's written every 5 s and whenever the app goes to the background. Offline earnings are capped
at 8 hours.

## Next ideas

- A big-number type (mantissa + exponent) before values pass ~1e15.
- Prestige / reset loop, more upgrades, a theme, sound, a proper launcher icon.
- Release signing (a release keystore, kept out of git) when it's time for Google Play.
