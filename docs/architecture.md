# Architecture

How the code is put together. What the game does is in `design.md`; how to write the code is
in `style-guide.md`.

## State and UI

- **`scripts/game.gd` is the autoload `Game`.** It holds all game state and economy logic, and
  has no UI. Scenes read its state, call its methods to tap and buy, and redraw on its `changed`
  signal.
- **Scenes are UI only.** The main screen's script builds the UI from `Game`'s data and drives
  any sub-scenes. A sub-scene's script handles only its own behaviour (such as the menu's
  sliding) and exposes the nodes the main screen needs.
- **Upgrades are data-driven.** Each upgrade is one entry in a data table in `game.gd`, and the
  UI generates each button and its text from that data. Adding an upgrade means adding one entry
  and touching nothing else.
- **Text that changes with the tap rate is rebuilt every frame**, since the tap rate changes
  without any `changed` signal.
- **Holds are driven by `is_pressed()` each frame**, not `button_up`, which never arrives if a
  button is disabled under the finger.
- **Gestures use mouse events**, which Android emulates from touch, so they behave the same on
  the desktop.
- **Android's back button is handled by the game** (`quit_on_go_back` is off), so it can close
  the menu before quitting. Quitting this way sends no close request, so the game saves first.

## Time and saving

- **Passive income follows the wall clock**, not the frame delta. Android stops calling
  `_process` while the app is in the background or the screen is locked, so the first frame
  back credits the whole gap, clamped. A cold start does the same from the time in the save.
- **The save is `user://save.json`**, written atomically (to a temporary file, then renamed)
  every few seconds and whenever the app loses focus or pauses, because Android can kill a
  backgrounded app without warning.
- **The save carries a format number.** Any change to the save's shape bumps it and adds a
  migration in the loader. Old saves must keep loading. The loader reads every field with a
  default and walks the upgrade table, so new upgrades load fine from old saves.

## Numbers

- **Numbers are plain `float`s.** The win caps points at the largest finite float, so nothing
  bigger is needed. Past about 1e16, floats drop low digits, but the display shows only three
  significant figures, and income is only lost when one frame's earnings are tiny next to the
  balance.
- **The win is derived, not stored**: it's whether points are at the cap. That holds because
  nothing earns or spends after a win. Income that overflows to `INF` still lands exactly on
  the cap.
- **Number and duration formatting** are pure static functions in `game.gd`, covered by tests.
  Run the tests after touching them.

## Build number

- `bin/phone export` writes a build number into a stamp file that's packed into the APK and
  deleted after the export. The game shows "(build N)" when the file exists and "(dev)" when it
  doesn't. The stamp file is never committed.
