# Development

How to build, test and run Tapperoni, and how the toolchain fits together. Setup and first-time
phone pairing are in the README.

## Scripts

Every recurring command is a script in `bin/`. Run a script with no arguments for its usage.

- `bin/phone` does everything in the Docker toolchain: the full check, tests, Android export,
  deploying to the phone, logs, and raw adb.
- `bin/desktop` uses the local Godot editor binary: opening the editor, running the tests, and a
  short headless run. Headless runs use a throwaway save, so they never touch the real one.

A command that will be run more than once goes into one of these scripts, not into a doc.

## Checking a change

- `bin/phone check` is the full check: a headless import, the tests, then a short run of the
  game, reporting any script errors and warnings. Run it after every change. There's no linter.
- To see a change on the phone, deploy it with `bin/phone`. If the phone can't be found, ask the
  user for the current "IP address & Port" from the phone's Wireless debugging screen. The port
  changes every time Wireless debugging is switched on.

## Tests

- Each `tests/test_*.gd` extends `tests/test_case.gd`, and its `test_*()` methods check results
  with `expect_eq`. `tests/run_tests.gd` finds and runs them, and fails if any test fails, a file
  doesn't load, or nothing matched the filter.
- Tests run before autoloads process a frame, so they never load or write the save. They test
  pure or static logic: preload a script under another name rather than using the `Game`
  autoload. A test that needs a game instance creates one outside the scene tree, so it never
  runs `_ready` or touches the save.
- `tests/` is excluded from the APK by the export preset.

## Toolchain

- Nothing is installed system-wide. The Godot editor is a single binary in
  `~/Applications/godot/`, and the Android toolchain (headless Godot, export templates, JDK,
  Android SDK, adb) is a Docker image defined in `docker/Dockerfile`.
- The container runs as the host user's uid, with the repo mounted at `/project` and the host's
  `~/.android` mounted for the adb keys and the debug keystore, so the APK signature survives
  image rebuilds. `bin/phone` creates `build/` and `~/.android` before starting the container;
  otherwise Docker would create them owned by root.
- `build/` holds a `.gdignore`, so Godot doesn't import what's there or pack it into the APK. Any
  other folder of non-game files inside the project (like `docs/`) needs one too.
- In `bin/phone`, paths used inside the container are relative to the project, and host-only
  state files are absolute. Each script's usage text is its header comment, printed when it runs
  with no arguments, so keep that comment up to date.
- The export uses Godot's prebuilt APK templates (no Gradle build), arm64 only, with the GL
  Compatibility renderer.
- GDScript autocomplete and diagnostics in VS Code only work while the Godot editor has this
  project open, because the editor serves the language server.

## Bumping versions

- **The game's version:** change `config/version` in `project.godot` and `version/name` in
  `export_presets.cfg`, and add 1 to `version/code` there (Android needs it to increase with
  every release). Also update the version label's placeholder text in the main scene. Commit,
  then tag `vX.Y.Z`.
- **Godot:** several places must agree. They are `GODOT_VERSION`, both SHA512s and the
  editor-settings filename in `docker/Dockerfile`; `IMAGE` in `bin/phone`; `GODOT` in
  `bin/desktop`; the editor path in `.vscode/settings.json`; `config/features` in
  `project.godot`; and the README. Rebuild the Docker image afterwards.
