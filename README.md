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

- **On the desktop:** open the project in the Godot editor (`bin/desktop editor`) and press F5,
  or use Run in VS Code.
- **On the phone** (Android 11+, same network as jupiter):
  1. Once: Settings → About phone → tap *Build number* 7 times. Then Developer options →
     **Wireless debugging** on → *Pair device with pairing code*, and run
     `bin/phone pair <ip:port> <code>` with the address and code shown there.
  2. Every time: `bin/phone deploy`. It exports a debug APK, installs it and launches it.
     If the phone isn't found, pass the *IP address & Port* from the Wireless debugging screen:
     `bin/phone deploy 192.168.0.42:37123`.
  3. `bin/phone logs` follows the game's `print()` output and errors from the phone.

`bin/phone check` loads the project headless, runs the tests and reports script errors.
`bin/desktop` does quick runs with the local editor binary instead of Docker. Run either script
with no arguments for everything it can do.

## Layout

| Path | What |
|---|---|
| `scripts/`, `scenes/` | The game: GDScript and the scenes it drives |
| `themes/` | The project theme: all colours, font sizes and styles |
| `icons/` | SVG icons |
| `tests/` | Headless tests |
| `docs/` | Design, architecture, development, style guide and release plan |
| `bin/` | Scripts for checking, testing, exporting and deploying |
| `docker/` | The Android toolchain image |

## Plans

The repo is https://github.com/DukeOfEtiquette/tapperoni, and planned work is tracked in its
GitHub issues.
