# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Tapperoni: an incremental tap game for Android, written in Godot 4.7 / GDScript. It's an exploration project. Nothing is installed system-wide: the Godot editor is a single binary at `~/Applications/godot/Godot_v4.7.2-stable_linux.x86_64`, and the whole Android toolchain (headless Godot, export templates, JDK 17, Android SDK, adb) runs in a Docker image driven by `bin/phone`.

## Commands

There's no linter. `bin/phone check` is the full check: a headless import, the tests, then about 30 frames of the game, reporting any script errors and warnings. Run it after every change.

```sh
bin/phone check                     # import + tests + ~30 frames, in Docker
bin/phone test [filter]             # only the tests; a filter runs those whose "file.method" contains it
# Without Docker (XDG_DATA_HOME keeps a desktop run from touching the real save):
GODOT=~/Applications/godot/Godot_v4.7.2-stable_linux.x86_64
$GODOT --headless --path . -s res://tests/run_tests.gd [-- <filter>]
XDG_DATA_HOME=$(mktemp -d) $GODOT --headless --path . --quit-after 30
```

**Tests:** each `tests/test_*.gd` extends `res://tests/test_case.gd`, and its `test_*()` methods check results with `expect_eq(actual, expected, what)`. `tests/run_tests.gd` finds and runs them. It exits non-zero if any test fails, if a file doesn't load, or if nothing matched. Tests run inside `_initialize`, before autoloads process a frame, so they never load or write the save. That means they test pure or static logic: preload a script under another name (`const GameScript := preload("res://scripts/game.gd")`) rather than using the `Game` autoload. `tests/` is excluded from the APK by `exclude_filter` in `export_presets.cfg`.

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
- **Upgrades are data-driven.** Each entry in `Game.UPGRADES` has a `name`, `base_cost`, `cost_growth`, `per_tap` and `per_second`, and the cost is `floor(base_cost * cost_growth ^ owned)`. `main.gd` builds one button per entry and generates its effect text ("+8 pts/sec") from the numbers, so adding an upgrade means adding one dictionary entry and touching nothing else. Never hard-code numbers that the data already holds into text. `per_tap()` and `per_second()` sum over every upgrade.
- **`scripts/main.gd` + `scenes/main.tscn`** are the only screen. Each upgrade button is an instance of `scenes/upgrade_button.tscn`. Nodes are looked up with unique names (`%CountLabel`, `%UpgradeList`, …), so keep `unique_name_in_owner` set on any node the script references. Holding an upgrade button repeat-buys at an accelerating rate (handled in `_process`, because `button_up` never fires if the button becomes disabled under the finger).
- **Saving:** the save is `user://save.json` (on desktop that's `~/.local/share/godot/app_userdata/Tapperoni/`). It's written atomically (to `.tmp`, then renamed) every 5 s and on pause/focus-out/close, because Android can kill a backgrounded app without warning. It carries `"save_format": SAVE_FORMAT` (currently 1). The earliest saves wrote `"version": 1` instead, which is the same format, so a missing `save_format` means 1. Bump `SAVE_FORMAT` and add a migration in `load_game` whenever the save's shape changes. `load_game` reads fields with `.get()` defaults and walks `UPGRADES`, which means new upgrades load fine from old saves. Any change to the save's shape needs the same backward compatibility.
- **Passive income follows the wall clock**, not the frame `delta`. `Game._process` credits `per_second() * (now - _last_tick)`, with the gap clamped to [0, 8 h]. This matters because Android stops calling `_process` while the app is in the background or the screen is locked. The first frame back then covers the whole gap and emits `returned_from_away(earned)` if the gap was ≥ `AWAY_MIN_GAP`. A cold start does the same from the save's `saved_at` and leaves the amount in `Game.offline_earned`. `main.gd` shows either case as the "While you were away" message.
- **Reset:** holding `%ResetButton` (top-left) for `RESET_HOLD_DURATION` (2 s) calls `Game.reset()`. Like hold-to-buy, it's driven by `is_pressed()` each frame, not `button_up`, which doesn't always arrive. There are no pop-up dialogs anywhere; destructive actions are hold-to-confirm.
- **Recommended upgrade:** `Game.payback_time(id, taps_per_second)` is the seconds to save up for an upgrade plus the seconds its extra income takes to repay its cost. Taps are valued at the given tap rate, and the result is `INF` if it never pays back. `main.gd` stars the lowest, valuing taps at the player's taps/sec over the last 10 s. The star only moves when another upgrade beats the current one by `RECOMMEND_SWITCH_MARGIN`, so it doesn't flicker.
- **Numbers are plain `float`s.** That's fine up to about 1.8e308. Past about 1e16 they drop low digits, but the display only shows three significant figures, and income is only lost when one frame's earnings are tiny next to the balance. Beyond 1.8e308 a value becomes `INF`. A mantissa/exponent type is only needed if the economy is meant to go past that. `Game.format_number` formats numbers as commas below 1e6, then K/M/B/T, then scientific notation from 1e15. The longer suffixes (Qa, Qi, Sx, …) were dropped because players couldn't tell which was bigger. It rounds before choosing the suffix or exponent, so 999,999,999 shows as `1.00B`, not `1000.00M`. `INF` shows as `Infinity`. `tests/test_format_number.gd` covers the edges, so run the tests after touching it.
- **`singularity` ("Pepperoni Singularity") is a deliberately unbalanced test upgrade:** Stronger Fingers' cost curve with +3e11 pts/sec each, so holding its button pushes numbers into scientific notation (1e15) in about 2 minutes. It isn't game design; remove it before a real release.
- **Build number:** `bin/phone export` increments `build/.build_number`, writes it to `build_stamp.txt` at the project root (the export preset's `include_filter` packs it into the APK), and deletes it after the export. `main.gd` shows "(build N)" when the file exists and "(dev)" when it doesn't. Don't commit `build_stamp.txt`.

## Toolchain details worth knowing

- The container runs as uid 1000 (matching the host user) with the repo mounted at `/project` and the host's `~/.android` mounted for the adb keys and the debug keystore, so the APK signature survives image rebuilds. `bin/phone` creates `build/` and `~/.android` before `docker run`; otherwise Docker would create them owned by root. It also puts a `.gdignore` in `build/`, so Godot doesn't import what's there (screenshots, logs) or pack it into the APK. Any other folder of non-game files inside the project needs a `.gdignore` too.
- In `bin/phone`, paths used inside the container are relative to the project (`APK`, `STAMP`), and host-only state files are absolute `*_FILE` variables. The usage text is the script's header comment, printed when it's run with no arguments, so keep that comment up to date.
- The export uses Godot's prebuilt APK templates (no Gradle build), arm64-v8a only, GL Compatibility renderer. Package: `io.github.dukeofetiquette.tapperoni`.
- **Bumping Godot** touches several places that must agree: `GODOT_VERSION` and both SHA512s in `docker/Dockerfile` (plus the `editor_settings-4.7.tres` filename there), `IMAGE` in `bin/phone`, the editor path in `.vscode/settings.json`, `config/features` in `project.godot`, and the README.
- `project.godot`, `export_presets.cfg` and `.tscn` files are normally edited by the Godot editor. Hand edits are fine, but keep the existing format.

## Conventions

GDScript follows Godot's style guide, plus these project rules:

- **Typing:** GDScript is indented with tabs (enforced in `.vscode/settings.json`). Everything is statically typed: `:=`, typed signatures, typed loop variables (`for id: String in UPGRADES`), and typed collections (`Array[float]`, `Dictionary[String, int]`). The exceptions are `UPGRADES` itself and JSON parsed from the save.
- **Full words:** members, functions and data keys use full words (`per_second`, `format_number`). Short locals in a small scope (`b`, `u`, `v`) are fine.
- **Durations:** always `float` seconds. Names carry no unit suffix; the `##` comment says "seconds".
- **Privacy:** anything only its own script uses gets a `_` prefix, including `@onready` node references. No prefix means another script uses it (e.g. `Game`'s API).
- **Node references:** a node that a script references is named `<Purpose><Type>` and marked unique, and its variable is that name in snake_case with a `_`: `%CountLabel` → `_count_label`, `%UpgradeList` → `_upgrade_list`. Layout-only nodes (`Margin`, `VBox`) are free-form.
- **Signal handlers:** methods connected to signals are named `_on_<emitter>_<signal>` (`_on_tap_button_pressed`, `_on_upgrade_button_down`, `_on_game_changed`) and are never called directly. Shared logic goes in a helper the handler calls (`_on_game_changed` → `_refresh`). Connecting straight to an engine method (`_away_label.hide`) is fine.
- **File layout:** first signals, constants, variables, then `@onready` variables. Then come `# ---- name ----` sections, padded with dashes to 96 columns. `lifecycle` (`_ready`, `_process`, `_notification`) comes first, then the script's own sections (`main.gd`: signal handlers, helpers; `game.gd`: economy, saving, formatting).
- **Tuning values** (timings, rates, economy numbers) are named constants.
- **Scenes:** a UI piece that repeats or has its own children is its own scene (`scenes/upgrade_button.tscn`), so its layout lives in a `.tscn` rather than in code. Icons are SVGs in `icons/`, and their colours are part of the art. Commit the `.import` file Godot generates next to each one (it appears after the editor or `bin/phone check` runs).
- **Styling:** all styling lives in `themes/default.tres`, the project-wide theme (`gui/theme/custom`): colours, font sizes and styleboxes. A node picks its look with `theme_type_variation`, and variations are named `<Role><BaseType>` (`HeadingLabel`, `StatLabel`, `UpgradeButton`, `BackgroundPanel`, …). Scenes and scripts never use `theme_override_*` for colours, fonts or styles. The one exception is container spacing (`theme_override_constants/margin_*`, `separation`), which is layout and stays in the scene. Size comes from the theme too: an upgrade button's height is its stylebox's content margins plus two lines of text.
- `.godot/` and `build/` are gitignored. Leave the `*.uid` and `*.import` files next to their sources committed.
