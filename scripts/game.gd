extends Node
## The game's state and economy (autoload "Game"). No UI here: scenes read the state and call
## tap() / buy(); the `changed` signal tells them to redraw.

signal changed

const SAVE_PATH := "user://save.json"
const SAVE_FORMAT := 1                 ## written as "save_format"; bump it when the save's shape changes
const SAVE_EVERY := 5.0                ## seconds between autosaves
const OFFLINE_CAP := 8 * 3600.0        ## seconds; at most 8 hours of offline earnings

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
var offline_earned := 0.0              ## set on load; the UI shows it once

var _since_save := 0.0                 ## seconds since the last save


# ---- lifecycle -------------------------------------------------------------------------------

func _ready() -> void:
	for id: String in UPGRADES:
		owned[id] = 0
	load_game()


func _process(delta: float) -> void:
	var rate := per_second()
	if rate > 0.0:
		_earn(rate * delta)
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
