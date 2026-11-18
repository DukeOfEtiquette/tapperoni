# Game design

How Tapperoni plays, and why. This is the place to record a design decision when a feature is
added or changed. Exact tuning values (timings, rates, costs) live in the code as named
constants, so they aren't repeated here.

## Core loop

- The currency is **points**. Tapping the big TAP! button earns points per tap.
- **Upgrades** cost points and add points per tap, points per second (passive income), or both.
  Each one's cost grows exponentially with how many you own.
- **Holding** an upgrade button keeps buying it, faster the longer it's held.

## Information the player always sees

- The points total, then the income: points per tap, taps per second, points per second from
  tapping, and points per second from upgrades. Every line shows even at zero; hiding a line
  hides information from the player.
- Each upgrade shows its effect, its cost, and a **countdown to affording it** at the current
  income (passive plus tapping at the current rate), so tapping faster visibly shortens it. It
  never shows zero while time is left, and shows a dash when there's no income at all.
- A **star** marks the recommended upgrade: the one that pays for itself soonest, counting the
  time to save up for it. It only moves when another upgrade is clearly better, so it doesn't
  flicker.
- A **countdown to winning**, worked out the same way as the upgrade countdowns.

## Time away

- Passive income keeps accruing while the app is in the background or closed, up to a cap.
- Coming back shows a "While you were away" message with what was earned. It stays up until
  the player acts: a tap, buying an upgrade, or a reset.

## Winning

- The game is won by reaching the most points there can be: the largest number a float can
  hold. Points stop there.
- After a win nothing earns or buys anything, TAP! is off, and "Congratulations, you won!" stays
  up until a reset.

## Menu and reset

- A menu slides in from the left, opened by the ☰ button in the top-left corner or a swipe in
  from the left edge. It follows the finger, and a flick opens or closes it however short it
  is. It closes with its own ☰ (in the same spot as the one that opened it), a tap beside it, a
  swipe back, or Android's back button.
- The menu holds **Reset progress**. Gameplay information (income, upgrades) stays on the main
  screen: you can't tap while the menu is open, and the upgrades are used constantly.
- There are no pop-up dialogs. Destructive actions, like reset, are hold-to-confirm.

## Numbers

- Below a million, numbers show with commas. Then K, M, B, T, then scientific notation. Longer
  suffixes (Qa, Qi, Sx, …) were dropped because players couldn't tell which was bigger.
- Numbers round before the suffix is chosen, so 999,999,999 shows as 1.00B, not 1000.00M.
- Long countdowns go from seconds up to minutes, hours, days and then years.

## Test content

- The **Singularity** upgrade is deliberately unbalanced, so the win can be reached in under a
  minute of hold-to-buy for testing. It isn't game design and goes before a release (see
  `release-plan.md`).
