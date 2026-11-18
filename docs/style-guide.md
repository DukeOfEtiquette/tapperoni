# Style guide

Rules for code, scenes and styling in this project. Examples are illustrative, not references
to real nodes or files.

## GDScript

GDScript follows Godot's style guide, plus these rules:

- **Indentation and typing:** tabs (enforced in `.vscode/settings.json`). Everything is
  statically typed: `:=`, typed signatures, typed loop variables (`for id: String in items`),
  and typed collections (`Array[float]`, `Dictionary[String, int]`). The exceptions are
  untyped data tables written as constants and JSON parsed from disk.
- **Full words:** members, functions and data keys use full words (`per_second`, not `pps`).
  Short locals in a small scope (`b`, `u`, `v`) are fine.
- **Durations** are always `float` seconds. Names carry no unit suffix; the `##` doc comment
  says "seconds".
- **Privacy:** anything only its own script uses gets a `_` prefix, including `@onready` node
  references. No prefix means another script uses it.
- **Tuning values** (timings, rates, sizes of gesture zones, economy numbers) are named
  constants, never literals in the logic.
- **Signal handlers** are named `_on_<emitter>_<signal>` (e.g. `_on_score_label_resized`) and
  are never called directly. Shared logic goes in a helper the handler calls. Connecting a
  signal straight to an existing method (`some_signal.connect(_some_label.hide)`) is fine.
- **File layout:** signals, then constants, then variables, then `@onready` variables. Then
  `# ---- name ----` sections, padded with dashes to 96 columns: `lifecycle` (`_ready`,
  `_process`, `_notification`) first, then the script's own sections.
- **Data-driven text:** never hard-code into UI text a number that data already holds; build
  the text from the data.

## Scenes and nodes

- **Node references:** a node a script references is named `<Purpose><Type>` and marked
  unique (`unique_name_in_owner`), and its variable is that name in snake_case with a `_`
  (e.g. `%ScoreLabel` → `_score_label`). Avoid names that collide with a Godot class (a
  `Button` called `MenuButton`). Layout-only nodes (`Margin`, `VBox`) are free-form.
- **Own scenes:** a UI piece that repeats, or has its own children, is its own scene, so its
  layout lives in a `.tscn` rather than in code. A script on a sub-scene exposes the nodes
  another script needs as public `@onready` variables.
- **Icons** are SVGs in `icons/`, and their colours are part of the art. Commit the `.import`
  file Godot generates next to each one.
- **No pop-up dialogs.** Destructive actions are hold-to-confirm, driven by `is_pressed()`
  each frame rather than `button_up`, which doesn't always arrive.

## Theme styling

- **All styling lives in the project theme** (`themes/default.tres`, set as
  `gui/theme/custom`): colours, font sizes and styleboxes.
- **A node picks its look with `theme_type_variation`.** Variations are named
  `<Role><BaseType>` (e.g. `ScoreLabel`, `PrimaryButton`).
- **No `theme_override_*` for colours, fonts or styles** in scenes or scripts. The one
  exception is container spacing (`theme_override_constants/margin_*`, `separation`), which is
  layout and stays in the scene.
- **Sizes come from the theme** where they can: a button's height follows from its stylebox's
  content margins and its font size, not from a fixed size in the scene.
- **Remove what nothing uses.** When a change leaves a variation or stylebox unused, delete it
  in the same change.

## Files

- `.godot/` and `build/` are gitignored. Keep the `*.uid` and `*.import` files next to their
  sources committed.
- `project.godot`, `export_presets.cfg` and `.tscn` files are normally written by the Godot
  editor. Hand edits are fine, but keep the existing format.
