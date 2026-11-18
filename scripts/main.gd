extends Control
## Main screen: the counter, the tap button and the upgrade list (built from Game.UPGRADES).

const TAP_WINDOW := 2.0            ## seconds of taps averaged for the taps/sec figure
const HOLD_DELAY := 0.35           ## seconds held before repeat-buying starts
const HOLD_FIRST_INTERVAL := 0.2   ## seconds between the first repeat buys...
const HOLD_SPEEDUP := 0.8          ## ...each interval this fraction of the one before...
const HOLD_MIN_INTERVAL := 0.05    ## ...down to this many seconds
const AWAY_MESSAGE_DURATION := 5.0 ## seconds the "while you were away" message stays up
const TAP_SQUASH_SCALE := 0.94     ## the tap button shrinks to this on each tap...
const TAP_SQUASH_IN := 0.05        ## ...over this many seconds...
const TAP_SQUASH_OUT := 0.08       ## ...and springs back over this many

var _upgrade_buttons: Dictionary[String, Button] = {}   ## upgrade id -> its button
var _tap_times: Array[float] = []  ## when the recent taps happened (seconds), oldest first
var _held_id := ""                 ## upgrade whose button is held down, "" if none
var _until_next_buy := 0.0         ## seconds until the next repeat buy
var _hold_interval := 0.0          ## current seconds between repeat buys

@onready var _count_label: Label = %CountLabel
@onready var _rate_label: Label = %RateLabel
@onready var _away_label: Label = %AwayLabel
@onready var _tap_button: Button = %TapButton
@onready var _upgrade_list: VBoxContainer = %UpgradeList
@onready var _version_label: Label = %VersionLabel


# ---- lifecycle -------------------------------------------------------------------------------

func _ready() -> void:
	_tap_button.pressed.connect(_on_tap_button_pressed)
	_version_label.text = _version_text()
	for id: String in Game.UPGRADES:
		var b := Button.new()
		b.theme_type_variation = &"UpgradeButton"
		# Hold to keep buying: one buy on touch, then repeats while held (see _process).
		b.button_down.connect(_on_upgrade_button_down.bind(id))
		b.button_up.connect(_on_upgrade_button_up)
		_upgrade_list.add_child(b)
		_upgrade_buttons[id] = b
	Game.changed.connect(_on_game_changed)
	if Game.offline_earned > 0.0:
		_away_label.text = "While you were away: +%s pepperoni" % Game.format_number(Game.offline_earned)
		_away_label.show()
		get_tree().create_timer(AWAY_MESSAGE_DURATION).timeout.connect(_away_label.hide)
	_refresh()


func _process(delta: float) -> void:
	# Taps/sec decays to 0 when you stop, so update it every frame, not only on changes.
	_update_rate()
	if _held_id != "":
		# The button may have been disabled under the finger (can't afford): then button_up
		# doesn't come, so stop as soon as it's no longer pressed.
		if not _upgrade_buttons[_held_id].is_pressed():
			_held_id = ""
			return
		_until_next_buy -= delta
		if _until_next_buy <= 0.0:
			_buy(_held_id)
			_hold_interval = maxf(HOLD_MIN_INTERVAL, _hold_interval * HOLD_SPEEDUP)
			_until_next_buy = _hold_interval


# ---- signal handlers -------------------------------------------------------------------------

func _on_tap_button_pressed() -> void:
	Game.tap()
	_tap_times.append(Time.get_ticks_msec() / 1000.0)
	# A little squash on each tap.
	_tap_button.pivot_offset = _tap_button.size / 2
	var t := create_tween()
	t.tween_property(_tap_button, "scale", Vector2.ONE * TAP_SQUASH_SCALE, TAP_SQUASH_IN)
	t.tween_property(_tap_button, "scale", Vector2.ONE, TAP_SQUASH_OUT)


func _on_upgrade_button_down(id: String) -> void:
	_buy(id)
	_held_id = id
	_until_next_buy = HOLD_DELAY
	_hold_interval = HOLD_FIRST_INTERVAL


func _on_upgrade_button_up() -> void:
	_held_id = ""


func _on_game_changed() -> void:
	_refresh()


# ---- helpers ---------------------------------------------------------------------------------

func _buy(id: String) -> void:
	var ok := Game.buy(id)
	print("buy %s: %s (owned %d)" % [id, "ok" if ok else "can't afford", Game.owned[id]])


func _refresh() -> void:
	_count_label.text = Game.format_number(Game.pepperoni)
	_update_rate()
	for id: String in _upgrade_buttons:
		var u: Dictionary = Game.UPGRADES[id]
		var b: Button = _upgrade_buttons[id]
		b.text = "%s (%d)\n%s · cost %s" % [u.name, Game.owned[id], _upgrade_effect_text(u), Game.format_number(Game.cost(id))]
		b.disabled = not Game.can_buy(id)


## What one more of an upgrade gives, from its numbers, worded like the rate line: "+1 per tap"
## and/or "+8 pts/sec".
func _upgrade_effect_text(u: Dictionary) -> String:
	var parts: Array[String] = []
	if u.per_tap > 0.0:
		parts.append("+%s per tap" % Game.format_number(u.per_tap))
	if u.per_second > 0.0:
		parts.append("+%s pts/sec" % Game.format_number(u.per_second))
	return ", ".join(parts)


## "N per tap · N.N taps/sec · N pts/sec" (pts/sec = per tap × taps/sec), plus the upgrades'
## passive income once there is any.
func _update_rate() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	while not _tap_times.is_empty() and now - _tap_times[0] > TAP_WINDOW:
		_tap_times.pop_front()
	var taps_per_second := _tap_times.size() / TAP_WINDOW
	var per_tap := Game.per_tap()
	var text := "%s per tap · %.1f taps/sec · %s pts/sec" % [
		Game.format_number(per_tap), taps_per_second, Game.format_number(per_tap * taps_per_second)]
	if Game.per_second() > 0.0:
		text += "\n+%s pts/sec from upgrades" % Game.format_number(Game.per_second())
	_rate_label.text = text


## "v0.1.0 (build 7)" for exported builds (bin/phone writes build_stamp.txt), "(dev)" in the editor.
func _version_text() -> String:
	var v := "v%s" % ProjectSettings.get_setting("application/config/version", "?")
	if FileAccess.file_exists("res://build_stamp.txt"):
		return "%s (build %s)" % [v, FileAccess.get_file_as_string("res://build_stamp.txt").strip_edges()]
	return v + " (dev)"
