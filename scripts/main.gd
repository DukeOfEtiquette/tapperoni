extends Control
## Main screen: the counter, the tap button and the upgrade list (built from Game.UPGRADES).

const UPGRADE_BUTTON_SCENE := preload("res://scenes/upgrade_button.tscn")

const RATE_TAP_WINDOW := 2.0       ## seconds of taps averaged for the taps/sec figure
const RECOMMEND_TAP_WINDOW := 10.0 ## seconds of taps averaged when valuing taps for the star
const RECOMMEND_SWITCH_MARGIN := 0.1   ## the star moves only to an upgrade this much better (10%)
const HOLD_DELAY := 0.35           ## seconds held before repeat-buying starts
const HOLD_FIRST_INTERVAL := 0.2   ## seconds between the first repeat buys...
const HOLD_SPEEDUP := 0.8          ## ...each interval this fraction of the one before...
const HOLD_MIN_INTERVAL := 0.05    ## ...down to this many seconds
const AWAY_MESSAGE_DURATION := 5.0 ## seconds the "while you were away" message stays up
const TAP_SQUASH_SCALE := 0.94     ## the tap button shrinks to this on each tap...
const TAP_SQUASH_IN := 0.05        ## ...over this many seconds...
const TAP_SQUASH_OUT := 0.08       ## ...and springs back over this many
const RESET_HOLD_DURATION := 2.0   ## seconds the reset button must be held to wipe progress
const RESET_TEXT := "Reset progress"

var _upgrade_buttons: Dictionary[String, Button] = {}   ## upgrade id -> its button
var _recommended_icons: Dictionary[String, TextureRect] = {}   ## upgrade id -> its star
var _recommended_id := ""          ## upgrade with the star, "" if none
var _tap_times: Array[float] = []  ## when the recent taps happened (seconds), oldest first
var _held_id := ""                 ## upgrade whose button is held down, "" if none
var _until_next_buy := 0.0         ## seconds until the next repeat buy
var _hold_interval := 0.0          ## current seconds between repeat buys
var _away_tween: Tween             ## hides the away message; replaced if it's shown again
var _reset_held_for := -1.0        ## seconds the reset button has been held; -1 if not held, or done

@onready var _count_label: Label = %CountLabel
@onready var _rate_label: Label = %RateLabel
@onready var _away_label: Label = %AwayLabel
@onready var _tap_button: Button = %TapButton
@onready var _upgrade_list: VBoxContainer = %UpgradeList
@onready var _version_label: Label = %VersionLabel
@onready var _reset_button: Button = %ResetButton


# ---- lifecycle -------------------------------------------------------------------------------

func _ready() -> void:
	_tap_button.pressed.connect(_on_tap_button_pressed)
	_reset_button.button_down.connect(_on_reset_button_down)
	_version_label.text = _version_text()
	for id: String in Game.UPGRADES:
		var b: Button = UPGRADE_BUTTON_SCENE.instantiate()
		# Hold to keep buying: one buy on touch, then repeats while held (see _process).
		b.button_down.connect(_on_upgrade_button_down.bind(id))
		b.button_up.connect(_on_upgrade_button_up)
		_upgrade_list.add_child(b)
		_upgrade_buttons[id] = b
		_recommended_icons[id] = b.get_node("RecommendedIcon")
	Game.changed.connect(_on_game_changed)
	Game.returned_from_away.connect(_on_game_returned_from_away)
	if Game.offline_earned > 0.0:
		_show_away_message(Game.offline_earned)
	_refresh()


func _process(delta: float) -> void:
	# Taps/sec decays to 0 when you stop, so these update every frame, not only on changes.
	_forget_old_taps()
	_update_rate()
	_update_recommendation()
	_update_upgrade_buttons()
	_update_reset_hold(delta)
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


func _on_reset_button_down() -> void:
	_reset_held_for = 0.0


func _on_game_changed() -> void:
	_refresh()


func _on_game_returned_from_away(earned: float) -> void:
	_show_away_message(earned)


# ---- helpers ---------------------------------------------------------------------------------

func _buy(id: String) -> void:
	var ok := Game.buy(id)
	print("buy %s: %s (owned %d)" % [id, "ok" if ok else "can't afford", Game.owned[id]])


func _refresh() -> void:
	_count_label.text = Game.format_number(Game.pepperoni)
	_update_rate()
	_update_upgrade_buttons()


## "Pizza Oven (3)" over "+1 pts/sec · cost 38 · 12.4s": the effect, the cost, and how long until
## it's affordable at the current tap rate plus passive income ("0.0s" once it is).
func _update_upgrade_buttons() -> void:
	var taps_per_second := _taps_per_second(RATE_TAP_WINDOW)   # the rate shown on screen
	for id: String in _upgrade_buttons:
		var u: Dictionary = Game.UPGRADES[id]
		var b: Button = _upgrade_buttons[id]
		b.text = "%s (%d)\n%s · cost %s · %s" % [u.name, Game.owned[id], _upgrade_effect_text(u),
			Game.format_number(Game.cost(id)), Game.format_duration(Game.time_to_afford(id, taps_per_second))]
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


## "While you were away: +N pepperoni", for a few seconds (after a cold start, or a return from
## the background).
func _show_away_message(earned: float) -> void:
	_away_label.text = "While you were away: +%s pepperoni" % Game.format_number(earned)
	_away_label.show()
	if _away_tween:
		_away_tween.kill()
	_away_tween = create_tween()
	_away_tween.tween_interval(AWAY_MESSAGE_DURATION)
	_away_tween.tween_callback(_away_label.hide)


## Hold-to-reset: counts down on the button while it's held, and wipes progress once it has been
## held for RESET_HOLD_DURATION. Letting go, or sliding off the button, cancels. Driven by the
## button's pressed state each frame rather than button_up, which doesn't always arrive.
func _update_reset_hold(delta: float) -> void:
	if not _reset_button.is_pressed():
		_reset_held_for = -1.0
		_reset_button.text = RESET_TEXT
		return
	if _reset_held_for < 0.0:   # already reset during this press; keep "Progress reset" up
		return
	_reset_held_for += delta
	if _reset_held_for >= RESET_HOLD_DURATION:
		_reset_held_for = -1.0   # done; the text stays until the button is released
		Game.reset()
		_tap_times.clear()
		_reset_button.text = "Progress reset"
	else:
		_reset_button.text = "Keep holding… %.1fs" % (RESET_HOLD_DURATION - _reset_held_for)


## Drops taps older than the longest window anything averages over.
func _forget_old_taps() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	while not _tap_times.is_empty() and now - _tap_times[0] > RECOMMEND_TAP_WINDOW:
		_tap_times.pop_front()


## Average taps/sec over the last `window` seconds.
func _taps_per_second(window: float) -> float:
	var now := Time.get_ticks_msec() / 1000.0
	var count := 0
	for t: float in _tap_times:
		if now - t <= window:
			count += 1
	return count / window


## "N per tap · N.N taps/sec · N pts/sec" (pts/sec = per tap × taps/sec), plus the upgrades'
## passive income once there is any.
func _update_rate() -> void:
	var taps_per_second := _taps_per_second(RATE_TAP_WINDOW)
	var per_tap := Game.per_tap()
	var text := "%s per tap · %.1f taps/sec · %s pts/sec" % [
		Game.format_number(per_tap), taps_per_second, Game.format_number(per_tap * taps_per_second)]
	if Game.per_second() > 0.0:
		text += "\n+%s pts/sec from upgrades" % Game.format_number(Game.per_second())
	_rate_label.text = text


## Stars the upgrade that pays for itself soonest (Game.payback_time), valuing taps at the recent
## tap rate. The star stays put unless another upgrade is clearly better, so it doesn't flicker.
func _update_recommendation() -> void:
	var taps_per_second := _taps_per_second(RECOMMEND_TAP_WINDOW)
	var best_id := ""
	var best_time := INF
	for id: String in Game.UPGRADES:
		var time := Game.payback_time(id, taps_per_second)
		if time < best_time:
			best_id = id
			best_time = time
	var current_time := Game.payback_time(_recommended_id, taps_per_second) if _recommended_id != "" else INF
	if current_time == INF or best_time < current_time * (1.0 - RECOMMEND_SWITCH_MARGIN):
		_recommended_id = best_id
	for id: String in _recommended_icons:
		_recommended_icons[id].visible = id == _recommended_id


## "v0.1.0 (build 7)" for exported builds (bin/phone writes build_stamp.txt), "(dev)" in the editor.
func _version_text() -> String:
	var v := "v%s" % ProjectSettings.get_setting("application/config/version", "?")
	if FileAccess.file_exists("res://build_stamp.txt"):
		return "%s (build %s)" % [v, FileAccess.get_file_as_string("res://build_stamp.txt").strip_edges()]
	return v + " (dev)"
