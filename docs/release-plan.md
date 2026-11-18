# Release plan

What has to happen before Tapperoni goes on Google Play, roughly in order. Feature work is
tracked in GitHub issues instead.

## Must do

- **Remove the Singularity test upgrade.** It's the `singularity` entry in `Game.UPGRADES`
  (`scripts/game.gd`), built to reach the win in about 45 seconds. Also update
  `tests/test_win.gd` (`test_time_to_win` uses it), and its mention in `design.md`.
- **Balance the economy and add more upgrades.** Without Singularity there are three upgrades,
  and a real game needs a path to the win (`Game.MAX_POINTS`, about 1.80e308) that takes the
  intended amount of play. Plain additive upgrades can't get there in any reasonable time, since
  costs grow exponentially while income only grows linearly, so this probably needs multipliers
  or prestige (see below).
- **A proper launcher icon.** The project still uses Godot's default `icon.svg`
  (`config/icon` in `project.godot`). The export preset has no Android-specific launcher icons
  set yet, including the adaptive foreground and background ones.
- **Release signing.** Exports are currently signed with the debug keystore from `~/.android`.
  Create a release keystore, keep it out of git (and back it up: losing it means the app can't
  be updated on Play), and pass it to the export without committing its passwords.
- **Build an Android App Bundle (AAB).** Google Play takes AABs for new apps, not APKs. That
  needs Godot's Gradle build (`gradle_build/use_gradle_build=true` in `export_presets.cfg`) and
  the Android build template installed in the project, which means adding Gradle to the Docker
  image and a new `bin/phone` command for a release export.
- **Check the target SDK** in the export preset against Play's current target API level
  requirement.
- **Bump the version** as described in `development.md`, then tag it.

## Maybe, for a first release

- **Prestige / a reset loop.** Right now a win ends the game until the player resets by hand.
  Prestige could turn that into a loop, and would also help with balancing (above).
- **Sound.**
