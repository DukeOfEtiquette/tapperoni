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

`bin/phone check` loads the project headless, runs the tests (`tests/`) and reports script errors.
`bin/phone test [filter]` runs only the tests.

## Layout

| Path | What |
|---|---|
| `scripts/game.gd` | Autoload `Game`: state, economy, upgrades (data in `UPGRADES`), saving, offline progress, number formatting |
| `scripts/main.gd`, `scenes/main.tscn` | The main screen; each upgrade button is a `scenes/upgrade_button.tscn` |
| `scripts/side_menu.gd`, `scenes/side_menu.tscn` | The slide-in menu, which holds the reset button |
| `themes/default.tres` | The project theme: all colours, font sizes and button styles |
| `icons/` | SVG icons (the recommended-upgrade star, the menu button) |
| `tests/` | Headless tests (`test_*.gd`), run by `bin/phone check` |
| `export_presets.cfg` | Android export preset (package `io.github.dukeofetiquette.tapperoni`, arm64) |
| `bin/phone` | Export / install / logs, via the Docker toolchain |

The save file is `user://save.json` (on desktop: `~/.local/share/godot/app_userdata/Tapperoni/`).
It's written every 5 s and whenever the app goes to the background. Time away, whether the app
was closed or just in the background, earns passive income, capped at 8 hours.

You win by reaching the most points there can be, about 1.80e308 (the largest number a float
can hold). After that, nothing earns or buys anything, and "Congratulations, you won!" stays up
until you reset.

To start over, open the menu (tap ☰ in the top-left, or swipe in from the left edge) and hold
*Reset progress* for 2 seconds.

The *Singularity* upgrade is deliberately unbalanced, to test winning: holding its button wins in
about 45 seconds. Remove it before a real release.

## Plans

The repo is https://github.com/DukeOfEtiquette/tapperoni, and planned work is tracked in its
GitHub issues.
