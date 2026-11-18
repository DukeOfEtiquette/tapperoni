extends Node
## The game's state and economy (autoload "Game"). No UI here: scenes read the state and call
## tap() / buy(); the `changed` signal tells them to redraw.

signal changed
## The app was suspended (in the background, or the screen locked) and has just been credited
## `earned` for the gap. The UI says so, like it does for offline_earned after a cold start.
signal returned_from_away(earned: float)

const SAVE_PATH := "user://save.json"
const SAVE_FORMAT := 2                 ## written as "save_format"; bump it when the save's shape changes
const SAVE_EVERY := 5.0                ## seconds between autosaves
const OFFLINE_CAP := 8 * 3600.0        ## seconds; at most 8 hours of offline earnings
const AWAY_MIN_GAP := 10.0             ## seconds between frames that count as having been away
## The most points there can be: the largest finite float. Reaching it wins the game, and nothing
## earns or spends after that until a reset.
const MAX_POINTS := 1.7976931348623157e308

## Upgrades: data-driven, so adding one is one entry here (the button text is generated from
## per_tap / per_second). cost = base_cost * cost_growth ^ owned
const UPGRADES := {
	"fingers": {"name": "Stronger Fingers",
		"base_cost": 10.0, "cost_growth": 1.15, "per_tap": 1.0, "per_second": 0.0},
	"oven": {"name": "Pizza Oven",
		"base_cost": 25.0, "cost_growth": 1.15, "per_tap": 0.0, "per_second": 1.0},
	"deli": {"name": "Deli Counter",
		"base_cost": 300.0, "cost_growth": 1.17, "per_tap": 0.0, "per_second": 8.0},
	# FOR TESTING, deliberately unbalanced: Stronger Fingers' cost curve with absurd income, so
	# ~40 s of hold-to-buy reaches MAX_POINTS and wins. Remove before a real release.
	"singularity": {"name": "Singularity",
		"base_cost": 10.0, "cost_growth": 1.15, "per_tap": 0.0, "per_second": 1e304},
}

## Number suffixes for format_number(), one per factor of 1000. Only the familiar ones: past T,
## scientific notation, where a bigger exponent is plainly a bigger number.
const SUFFIXES := ["", "K", "M", "B", "T"]

var points := 0.0
var total_earned := 0.0
var owned: Dictionary[String, int] = {}   ## upgrade id -> count
var offline_earned := 0.0              ## earned while closed, set on load; the UI shows it once

var _since_save := 0.0                 ## seconds since the last save
var _last_tick := 0.0                  ## Unix time (seconds) of the last _process


# ---- lifecycle -------------------------------------------------------------------------------

func _ready() -> void:
	for id: String in UPGRADES:
		owned[id] = 0
	load_game()
	_last_tick = Time.get_unix_time_from_system()


## Passive income follows the wall clock, not the frame delta: Android stops calling _process
## while the app is in the background or the screen is locked, and the first frame back then
## covers the whole gap (capped like offline earnings).
func _process(delta: float) -> void:
	var now := Time.get_unix_time_from_system()
	var elapsed := clampf(now - _last_tick, 0.0, OFFLINE_CAP)   # a clock set backwards gives 0
	_last_tick = now
	var earned := _earn(per_second() * elapsed)
	if earned > 0.0:
		if elapsed >= AWAY_MIN_GAP:
			returned_from_away.emit(earned)
	_since_save += delta
	if _since_save >= SAVE_EVERY:
		save_game()


## Android may kill a backgrounded app without warning, so save whenever we lose focus.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		save_game()


# ---- economy ---------------------------------------------------------------------------------

func per_tap() -> float:
	var v := 1.0
	for id: String in UPGRADES:
		v += UPGRADES[id].per_tap * owned[id]
	return v


func per_second() -> float:
	var v := 0.0
	for id: String in UPGRADES:
		v += UPGRADES[id].per_second * owned[id]
	return v


func cost(id: String) -> float:
	var u: Dictionary = UPGRADES[id]
	return floor(u.base_cost * pow(u.cost_growth, owned[id]))


func can_buy(id: String) -> bool:
	return not has_won() and points >= cost(id)


## True once points have reached MAX_POINTS. It lasts until reset(), since nothing can spend them.
func has_won() -> bool:
	return points >= MAX_POINTS


## Seconds until `id` is affordable at the current income: per_second() plus per_tap() at
## `taps_per_second`. 0 if it already is; INF if it isn't and there's no income, or the game is
## won (nothing can be bought).
func time_to_afford(id: String, taps_per_second: float) -> float:
	if has_won():
		return INF
	return _time_to_reach(cost(id), taps_per_second)


## Seconds until points reach MAX_POINTS and the game is won, at the same income as
## time_to_afford. 0 once won; INF if there's no income.
func time_to_win(taps_per_second: float) -> float:
	return _time_to_reach(MAX_POINTS, taps_per_second)


## Seconds until buying `id` has paid for itself: the wait to afford it (time_to_afford), plus
## the time its extra income takes to earn its cost back. Taps are valued at `taps_per_second`.
## INF if it never would (no income to save up with, or nothing gained). The lowest is the best
## next buy.
func payback_time(id: String, taps_per_second: float) -> float:
	var u: Dictionary = UPGRADES[id]
	var gain: float = u.per_second + u.per_tap * taps_per_second
	if gain <= 0.0:
		return INF
	return time_to_afford(id, taps_per_second) + cost(id) / gain   # INF + anything is INF


func tap() -> float:
	return _earn(per_tap())


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	points -= cost(id)
	owned[id] += 1
	changed.emit()
	return true


## Wipes all progress and saves (the main screen's hold-to-reset button).
func reset() -> void:
	points = 0.0
	total_earned = 0.0
	for id: String in UPGRADES:
		owned[id] = 0
	save_game()
	changed.emit()


## Adds `amount`, up to MAX_POINTS, and returns what was actually added: less than `amount` at
## the cap, 0 once the game is won. `amount` may be INF (per_second() can overflow); never NaN,
## since only positive amounts get through.
## Seconds until points reach `target` at per_second() plus per_tap() at `taps_per_second`. 0 if
## they already have; INF if they haven't and there's no income.
func _time_to_reach(target: float, taps_per_second: float) -> float:
	var shortfall := target - points
	if shortfall <= 0.0:
		return 0.0
	var income := per_second() + per_tap() * taps_per_second
	return shortfall / income if income > 0.0 else INF


func _earn(amount: float) -> float:
	if not amount > 0.0 or has_won():
		return 0.0
	var gained := minf(amount, MAX_POINTS - points)
	points = minf(points + amount, MAX_POINTS)   # not points + gained: that can round short of the cap
	total_earned = minf(total_earned + gained, MAX_POINTS)
	changed.emit()
	return gained


# ---- saving ----------------------------------------------------------------------------------

func save_game() -> void:
	_since_save = 0.0
	var data := {
		"save_format": SAVE_FORMAT,
		"saved_at": Time.get_unix_time_from_system(),
		"points": points,
		"total_earned": total_earned,
		"owned": owned,
	}
	var f := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if f == null:
		push_error("save failed: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)   # never leave a half-written save


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("save file unreadable; starting fresh")
		return
	# The earliest saves say "version": 1 instead of "save_format", so a missing one means 1.
	var save_format := int(data.get("save_format", 1))
	# Format 1 called the points "pepperoni"; otherwise the shape is the same.
	points = minf(float(data.get("points" if save_format >= 2 else "pepperoni", 0.0)), MAX_POINTS)
	total_earned = float(data.get("total_earned", 0.0))
	var saved_owned: Dictionary = data.get("owned", {})
	for id: String in UPGRADES:
		owned[id] = int(saved_owned.get(id, 0))
	# Offline progress, clamped: a clock set backwards gives 0, forwards at most OFFLINE_CAP.
	var away := clampf(Time.get_unix_time_from_system() - float(data.get("saved_at", 0.0)), 0.0, OFFLINE_CAP)
	offline_earned = _earn(per_second() * away)


# ---- formatting ------------------------------------------------------------------------------

## A countdown: "0.0s" ... "59.9s", "4m 05s", "2h 13m", "3d 04h", then years ("12.5y", "4,500y").
## Rounds up, so it reads "0.0s" only at zero, never while there's still time left. "—" for
## INF (never).
static func format_duration(seconds: float) -> String:
	if is_nan(seconds) or is_inf(seconds):
		return "—"
	seconds = maxf(seconds, 0.0)
	if seconds < 1e9:   # ~32 years: small enough for whole numbers (beyond, ceili overflows)
		var tenths := ceili(seconds * 10.0)
		if tenths < 600:
			return "%.1fs" % (tenths / 10.0)
		var total_seconds := ceili(seconds)
		if total_seconds < 3600:
			return "%dm %02ds" % [total_seconds / 60, total_seconds % 60]
		var total_minutes := ceili(seconds / 60.0)
		if total_minutes < 24 * 60:
			return "%dh %02dm" % [total_minutes / 60, total_minutes % 60]
		var total_hours := ceili(seconds / 3600.0)
		if total_hours < 365 * 24:
			return "%dd %02dh" % [total_hours / 24, total_hours % 24]
	var years := seconds / (365.25 * 24 * 3600)
	if years < 1000.0:
		return "%.1fy" % years
	return format_number(years) + "y"



## 1234 -> "1,234", 1234567 -> "1.23M"; from 1e15, past T, scientific ("4.56e15").
## Rounds first, then picks the suffix or exponent, so 999,999,999 is "1.00B", not "1000.00M".
## Plain floats are fine up to ~1e308 (past ~1e16 they drop digits nobody sees); beyond that
## they're INF, shown as "Infinity" rather than failing.
static func format_number(n: float) -> String:
	if is_nan(n):
		return "?"
	if n < 0.0:
		return "-" + format_number(-n)
	if is_inf(n):
		return "Infinity"
	n = floor(n)
	if n < 1e6:
		var s := str(int(n))
		var out := ""
		for i in s.length():
			if i > 0 and (s.length() - i) % 3 == 0:
				out += ","
			out += s[i]
		return out
	# log() can land a hair either side of a whole number (log10(1e36) -> 35.999...), so check.
	var exponent := int(floor(log(n) / log(10.0)))
	if pow(10.0, exponent) > n:
		exponent -= 1
	elif pow(10.0, exponent + 1) <= n:
		exponent += 1
	var tier := exponent / 3
	if tier < SUFFIXES.size():
		var value := n / pow(1000.0, tier)
		if snappedf(value, 0.01) < 1000.0:
			return "%.2f%s" % [value, SUFFIXES[tier]]
		if tier + 1 < SUFFIXES.size():   # rounds up into the next suffix
			return "%.2f%s" % [value / 1000.0, SUFFIXES[tier + 1]]
	var mantissa := n / pow(10.0, exponent)
	if snappedf(mantissa, 0.01) >= 10.0:   # rounds up to the next power of ten
		mantissa /= 10.0
		exponent += 1
	return "%.2fe%d" % [mantissa, exponent]
