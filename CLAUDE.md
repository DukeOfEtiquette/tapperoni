# CLAUDE.md

Tapperoni is an incremental tap game for Android, written in Godot 4.7 / GDScript. It's an
exploration project.

Read the doc for the task at hand:

- `docs/development.md`: building, testing, running and deploying, and the toolchain.
- `docs/architecture.md`: how the code is put together.
- `docs/design.md`: how the game plays. Record design decisions here.
- `docs/style-guide.md`: rules for code, scenes and theme styling.
- `docs/release-plan.md`: what's left before a Play Store release.
- Planned work is tracked in the repo's GitHub issues.

Run `bin/phone check` after every change.

Keep this file thin. It changes only when a doc is added, moved or removed. A new or changed
feature is recorded in `docs/design.md`, never here. A recurring command goes into a script in
`bin/`, never into a doc.
