extends Node
## The game's state and economy (autoload "Game"). No UI here: scenes read the state and call
## tap() / buy(); the `changed` signal tells them to redraw.

signal changed
## The app was suspended (in the background, or the screen locked) and has just been credited
## `earned` for the gap. The UI says so, like it does for offline_earned after a cold start.
signal returned_from_away(earned: float)

const SAVE_PATH := "user://save.json"
const SAVE_FORMAT := 1                 ## written as "save_format"; bump it when the save's shape changes
const SAVE_EVERY := 5.0                ## seconds between autosaves
const OFFLINE_CAP := 8 * 3600.0        ## seconds; at most 8 hours of offline earnings
const AWAY_MIN_GAP := 10.0             ## seconds between frames that count as having been away

## Upgrades: data-driven, so adding one is one entry here (the button text is generated from
## per_tap / per_second). cost = base_cost * cost_growth ^ owned
const UPGRADES := {
	"fingers": {"name": "Stronger Fingers",
		"base_cost": 10.0, "cost_growth": 1.15, "per_tap": 1.0, "per_second": 0.0},
	"oven": {"name": "Pizza Oven",
		"base_cost": 25.0, "cost_growth": 1.15, "per_tap": 0.0, "per_second": 1.0},
	"deli": {"name": "Deli Counter",
		"base_cost": 300.0, "cost_growth": 1.17, "per_tap": 0.0, "per_second": 8.0},
}

## Number suffixes for format_number(), one per factor of 1000.
const SUFFIXES := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

var pepperoni := 0.0
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
	var earned := per_second() * elapsed
	if earned > 0.0:
		_earn(earned)
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
	return pepperoni >= cost(id)


## Seconds until buying `id` has paid for itself: the wait to afford it at the current income,
## plus the time its extra income takes to earn its cost back. Taps are valued at
## `taps_per_second`. INF if it never would (no income to save up with, or nothing gained).
## The lowest is the best next buy.
func payback_time(id: String, taps_per_second: float) -> float:
	var u: Dictionary = UPGRADES[id]
	var gain: float = u.per_second + u.per_tap * taps_per_second
	if gain <= 0.0:
		return INF
	var income := per_second() + per_tap() * taps_per_second
	var shortfall := maxf(0.0, cost(id) - pepperoni)
	if shortfall > 0.0 and income <= 0.0:
		return INF
	var wait := shortfall / income if shortfall > 0.0 else 0.0
	return wait + cost(id) / gain


func tap() -> float:
	var gained := per_tap()
	_earn(gained)
	return gained


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	pepperoni -= cost(id)
	owned[id] += 1
	changed.emit()
	return true


## Wipes all progress and saves. Nothing calls it yet (no UI for it).
func reset() -> void:
	pepperoni = 0.0
	total_earned = 0.0
	for id: String in UPGRADES:
		owned[id] = 0
	save_game()
	changed.emit()


func _earn(amount: float) -> void:
	pepperoni += amount
	total_earned += amount
	changed.emit()


# ---- saving ----------------------------------------------------------------------------------

func save_game() -> void:
	_since_save = 0.0
	var data := {
		"save_format": SAVE_FORMAT,
		"saved_at": Time.get_unix_time_from_system(),
		"pepperoni": pepperoni,
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
	# No migrations yet: every save so far is format 1. (The earliest ones say "version": 1
	# instead of "save_format"; when format 2 comes, treat a missing "save_format" as 1.)
	pepperoni = float(data.get("pepperoni", 0.0))
	total_earned = float(data.get("total_earned", 0.0))
	var saved_owned: Dictionary = data.get("owned", {})
	for id: String in UPGRADES:
		owned[id] = int(saved_owned.get(id, 0))
	# Offline progress, clamped: a clock set backwards gives 0, forwards at most OFFLINE_CAP.
	var away := clampf(Time.get_unix_time_from_system() - float(data.get("saved_at", 0.0)), 0.0, OFFLINE_CAP)
	offline_earned = per_second() * away
	if offline_earned > 0.0:
		_earn(offline_earned)


# ---- formatting ------------------------------------------------------------------------------

## 1234 -> "1,234", 1234567 -> "1.23M"; beyond the suffixes, scientific notation.
## Note: floats lose precision past ~1e15 and overflow at ~1e308. Swap in a mantissa/exponent
## number type before the economy gets that big.
static func format_number(n: float) -> String:
	n = floor(n)
	if n < 1e6:
		var s := str(int(n))
		var out := ""
		for i in s.length():
			if i > 0 and (s.length() - i) % 3 == 0:
				out += ","
			out += s[i]
		return out
	var tier := int(floor(log(n) / log(1000.0)))
	if tier < SUFFIXES.size():
		return "%.2f%s" % [n / pow(1000.0, tier), SUFFIXES[tier]]
	return "%.2fe%d" % [n / pow(10.0, floor(log(n) / log(10.0))), int(floor(log(n) / log(10.0)))]
