# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Tapperoni: an incremental tap game for Android, written in Godot 4.7 / GDScript. It's an exploration project. Nothing is installed system-wide: the Godot editor is a single binary at `~/Applications/godot/Godot_v4.7.2-stable_linux.x86_64`, and the whole Android toolchain (headless Godot, export templates, JDK 17, Android SDK, adb) runs in a Docker image driven by `bin/phone`.

## Commands

There are no unit tests and no linter. The way to check the code is to load the project headless and look for script errors:

```sh
bin/phone check                     # headless import + ~30 frames of the game in Docker; prints errors/warnings
~/Applications/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --quit-after 30   # same check, without Docker
```

Android (needs the image built once with `bin/phone build-image`, again after a Godot version bump):

```sh
bin/phone export                    # build/tapperoni.apk only (log in build/export.log)
bin/phone deploy [ip:port]          # export, install and launch on the phone over Wireless debugging
bin/phone logs [ip:port]            # follow print() output and errors (logcat -s godot)
bin/phone adb <args>                # any adb command against the connected phone
bin/phone pair <ip:port> <code>     # one-time pairing
```

`deploy`/`logs`/`adb` reach the phone at the given address, else the last one that worked (`build/.device`), else via mDNS. The port changes every time Wireless debugging is toggled. If the phone can't be found, you'll need the user to give you the current "IP address & Port".

On the desktop the game runs from the Godot editor (F5) or VS Code's `godot-tools` (Run). GDScript autocomplete and diagnostics in VS Code only work while the Godot editor has this project open, because the editor serves the language server.

## Architecture

- **`scripts/game.gd` is the autoload `Game`** (registered in `project.godot`). It holds all state and economy logic and has no UI. Scenes read its state, call `Game.tap()` / `Game.buy(id)`, and redraw on the `Game.changed` signal. Passive income ticks in `Game._process`.
- **Upgrades are data-driven.** Each entry in `Game.UPGRADES` has a `name`, `desc`, `base_cost`, `cost_growth`, `per_tap` and `per_sec`, and the cost is `floor(base_cost * cost_growth ^ owned)`. `main.gd` builds one button per entry, so adding an upgrade means adding one dictionary entry and touching nothing else. `per_tap()` and `per_second()` sum over every upgrade.
- **`scripts/main.gd` + `scenes/main.tscn`** are the only screen. Nodes are looked up with unique names (`%Count`, `%Upgrades`, …), so keep `unique_name_in_owner` set on any node the script references. Holding an upgrade button repeat-buys at an accelerating rate (handled in `_process`, because `button_up` never fires if the button becomes disabled under the finger).
- **Saving:** the save is `user://save.json` (on desktop that's `~/.local/share/godot/app_userdata/Tapperoni/`). It's written atomically (to `.tmp`, then renamed) every 5 s and on pause/focus-out/close, because Android can kill a backgrounded app without warning. It carries `"version": 1`. `load_game` reads fields with `.get()` defaults and walks `UPGRADES`, which means new upgrades load fine from old saves. Any change to the save's shape needs the same backward compatibility.
- **Offline earnings** are `per_second() * time away`, with the time away clamped to [0, 8 h]. `main.gd` shows them once through `Game.offline_earned`.
- **Numbers are plain `float`s.** `Game.fmt` formats them (commas below 1e6, then K/M/B/… suffixes, then scientific). Precision is lost past ~1e15; the README's plan is a mantissa/exponent type before the economy gets that big.
- **Build number:** `bin/phone export` increments `build/.build_number`, writes it to `build_stamp.txt` at the project root (the export preset's `include_filter` packs it into the APK), and deletes it after the export. `main.gd` shows "(build N)" when the file exists and "(dev)" when it doesn't. Don't commit `build_stamp.txt`.

## Toolchain details worth knowing

- The container runs as uid 1000 (matching the host user) with the repo mounted at `/project` and the host's `~/.android` mounted for the adb keys and the debug keystore, so the APK signature survives image rebuilds. `bin/phone` creates `build/` and `~/.android` before `docker run`; otherwise Docker would create them owned by root. It also puts a `.gdignore` in `build/`, so Godot doesn't import what's there (screenshots, logs) or pack it into the APK. Any other folder of non-game files inside the project needs a `.gdignore` too.
- The export uses Godot's prebuilt APK templates (no Gradle build), arm64-v8a only, GL Compatibility renderer. Package: `io.github.dukeofetiquette.tapperoni`.
- **Bumping Godot** touches several places that must agree: `GODOT_VERSION` and both SHA512s in `docker/Dockerfile` (plus the `editor_settings-4.7.tres` filename there), `IMAGE` in `bin/phone`, the editor path in `.vscode/settings.json`, `config/features` in `project.godot`, and the README.
- `project.godot`, `export_presets.cfg` and `.tscn` files are normally edited by the Godot editor. Hand edits are fine, but keep the existing format.

## Conventions

- GDScript is indented with tabs (enforced in `.vscode/settings.json`) and uses static typing (`:=`, typed signatures). `##` doc comments describe intent.
- `.godot/` and `build/` are gitignored. Leave the `*.uid` and `*.import` files next to their sources committed.
