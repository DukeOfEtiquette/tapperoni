extends Control
## Main screen: the counter, the tap button and the upgrade list (built from Game.UPGRADES).

@onready var count_label: Label = %Count
@onready var rate_label: Label = %Rate
@onready var tap_button: Button = %TapButton
@onready var upgrade_list: VBoxContainer = %Upgrades
@onready var away_label: Label = %Away
@onready var version_label: Label = %Version

var _upgrade_buttons := {}   ## upgrade id -> Button

const TAP_WINDOW := 2.0      ## seconds of taps averaged for the taps/sec figure
var _tap_times: Array[float] = []

const HOLD_DELAY := 0.35     ## seconds held before repeat-buying starts
const HOLD_FIRST := 0.2      ## first repeat interval; it speeds up to HOLD_FASTEST
const HOLD_FASTEST := 0.05
var _held := ""              ## upgrade id being held, "" if none
var _hold_next := 0.0        ## seconds until the next repeat buy
var _hold_interval := 0.0


func _ready() -> void:
	tap_button.pressed.connect(_on_tap)
	version_label.text = _version_text()
	for id in Game.UPGRADES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 104)
		b.add_theme_font_size_override("font_size", 26)
		_style_upgrade(b)
		# Hold to keep buying: one buy on touch, then repeats while held (see _process).
		b.button_down.connect(_hold_start.bind(id))
		b.button_up.connect(_hold_stop)
		upgrade_list.add_child(b)
		_upgrade_buttons[id] = b
	Game.changed.connect(_refresh)
	if Game.offline_earned > 0.0:
		away_label.text = "While you were away: +%s pepperoni" % Game.fmt(Game.offline_earned)
		away_label.show()
		get_tree().create_timer(5.0).timeout.connect(away_label.hide)
	_refresh()


func _process(delta: float) -> void:
	# Taps/sec decays to 0 when you stop, so update it every frame, not only on changes.
	_update_rate()
	if _held != "":
		# The button may have been disabled under the finger (can't afford): then button_up
		# doesn't come, so stop as soon as it's no longer pressed.
		if not _upgrade_buttons[_held].is_pressed():
			_hold_stop()
			return
		_hold_next -= delta
		if _hold_next <= 0.0:
			_on_buy(_held)
			_hold_interval = maxf(HOLD_FASTEST, _hold_interval * 0.8)
			_hold_next = _hold_interval


func _hold_start(id: String) -> void:
	_on_buy(id)
	_held = id
	_hold_next = HOLD_DELAY
	_hold_interval = HOLD_FIRST


func _hold_stop() -> void:
	_held = ""


func _on_tap() -> void:
	Game.tap()
	_tap_times.append(Time.get_ticks_msec() / 1000.0)
	# A little squash on each tap.
	tap_button.pivot_offset = tap_button.size / 2
	var t := create_tween()
	t.tween_property(tap_button, "scale", Vector2(0.94, 0.94), 0.05)
	t.tween_property(tap_button, "scale", Vector2.ONE, 0.08)


func _on_buy(id: String) -> void:
	var ok := Game.buy(id)
	print("buy %s: %s (owned %d)" % [id, "ok" if ok else "can't afford", Game.owned[id]])


## Upgrade buttons look like buttons: rounded, bordered, amber when affordable, dim when not.
func _style_upgrade(b: Button) -> void:
	var make := func(bg: Color, border: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = bg
		s.border_color = border
		s.set_border_width_all(3)
		s.set_corner_radius_all(18)
		s.set_content_margin_all(12)
		return s
	b.add_theme_stylebox_override("normal", make.call(Color(0.42, 0.2, 0.08), Color(1, 0.7, 0.35)))
	b.add_theme_stylebox_override("hover", make.call(Color(0.5, 0.25, 0.1), Color(1, 0.8, 0.45)))
	b.add_theme_stylebox_override("pressed", make.call(Color(0.6, 0.32, 0.12), Color(1, 0.9, 0.6)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", make.call(Color(0.2, 0.12, 0.09), Color(0.35, 0.25, 0.2)))
	b.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.5, 0.45))


func _refresh() -> void:
	count_label.text = Game.fmt(Game.pepperoni)
	_update_rate()
	for id in _upgrade_buttons:
		var u: Dictionary = Game.UPGRADES[id]
		var b: Button = _upgrade_buttons[id]
		b.text = "%s (%d)\n%s · cost %s" % [u.name, Game.owned[id], u.desc, Game.fmt(Game.cost(id))]
		b.disabled = not Game.can_buy(id)


## "N per tap · X taps/sec", plus the upgrades' passive income once there is any.
func _update_rate() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	while not _tap_times.is_empty() and now - _tap_times[0] > TAP_WINDOW:
		_tap_times.pop_front()
	var taps_per_sec := _tap_times.size() / TAP_WINDOW
	var text := "%s per tap · %.1f taps/sec" % [Game.fmt(Game.per_tap()), taps_per_sec]
	if Game.per_second() > 0.0:
		text += "\n+%s per second from upgrades" % Game.fmt(Game.per_second())
	rate_label.text = text


## "v0.1.0 (build 7)" for exported builds (bin/phone writes build_stamp.txt), "(dev)" in the editor.
func _version_text() -> String:
	var v := "v%s" % ProjectSettings.get_setting("application/config/version", "?")
	if FileAccess.file_exists("res://build_stamp.txt"):
		return "%s (build %s)" % [v, FileAccess.get_file_as_string("res://build_stamp.txt").strip_edges()]
	return v + " (dev)"
