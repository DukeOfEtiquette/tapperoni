class_name SideMenu
extends Control
## A drawer that slides in from the left with the reset button.
## It opens with open() (main.gd's menu button) or a swipe from the left edge, and closes with its
## own menu button, a tap beside it, a swipe back to the left, or close() (main.gd, on Android's
## back button). A drag moves it with the finger; letting go snaps it open or shut, whichever way
## a flick was going, else by how far out it is. This script only moves the drawer: main.gd drives
## reset_button.

const SLIDE_DURATION := 0.2         ## seconds to slide all the way open or shut
const EDGE_SWIPE_WIDTH := 40.0      ## px from the left edge where a swipe can start opening it
const SNAP_OPEN_FRACTION := 0.5     ## a released slow drag snaps open past this fraction, else shut
const FLICK_SPEED := 400.0          ## px/s sideways; a release this fast snaps the way it was going
const FLICK_WINDOW := 0.1           ## seconds; a drag that stopped this long before release isn't a flick
const SPEED_SMOOTHING := 0.5        ## weight of each new motion event in the drag speed (0 to 1)
const TAP_MOVE_LIMIT := 16.0        ## px; a touch beside the drawer moving less is a tap (closes)

var is_open := false                ## where the drawer is headed; false while it's dragged from shut

var _open_amount := 0.0             ## how far out the drawer is: 0 (hidden) to 1 (all the way)
var _slide_tween: Tween
var _dragging := false              ## a touch that started on the drawer, beside it, or at the edge
var _drag_start_amount := 0.0       ## _open_amount when the drag started
var _drag_distance := 0.0           ## px moved sideways since the drag started (right is +)
var _drag_speed := 0.0              ## px/s sideways, smoothed over recent motion (right is +)
var _last_move_time := 0.0          ## seconds (engine ticks) of the drag's last motion, or its start

@onready var reset_button: Button = %ResetButton
@onready var _shade_panel: Panel = %ShadePanel
@onready var _drawer_panel: Panel = %DrawerPanel
@onready var _close_button: Button = %CloseButton
@onready var _edge_swipe_area: Control = %EdgeSwipeArea


# ---- lifecycle -------------------------------------------------------------------------------

func _ready() -> void:
	_edge_swipe_area.offset_right = EDGE_SWIPE_WIDTH
	_edge_swipe_area.gui_input.connect(_on_edge_swipe_area_gui_input)
	_shade_panel.gui_input.connect(_on_shade_panel_gui_input)
	_drawer_panel.gui_input.connect(_on_drawer_panel_gui_input)
	_drawer_panel.resized.connect(_on_drawer_panel_resized)
	_close_button.pressed.connect(close)
	_set_open_amount(0.0)


# ---- opening and closing ---------------------------------------------------------------------

func open() -> void:
	_slide_to(true)


func close() -> void:
	_slide_to(false)


# ---- signal handlers -------------------------------------------------------------------------

func _on_edge_swipe_area_gui_input(event: InputEvent) -> void:
	_handle_drag(event, false)


func _on_shade_panel_gui_input(event: InputEvent) -> void:
	_handle_drag(event, true)


func _on_drawer_panel_gui_input(event: InputEvent) -> void:
	_handle_drag(event, false)


func _on_drawer_panel_resized() -> void:
	_set_open_amount(_open_amount)   # keep the same fraction showing at the new width


# ---- helpers ---------------------------------------------------------------------------------

## Follows a drag from the left edge, the drawer, or the shade beside it, then snaps open or shut
## on release; a tap on the shade (`tap_closes`) closes it. Mouse events, which Android emulates
## from touch, so it works the same on the desktop.
func _handle_drag(event: InputEvent, tap_closes: bool) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if button.pressed:
			if _slide_tween:
				_slide_tween.kill()
			_dragging = true
			_drag_start_amount = _open_amount
			_drag_distance = 0.0
			_drag_speed = 0.0
			_last_move_time = _now()
		elif _dragging:
			_dragging = false
			if _now() - _last_move_time > FLICK_WINDOW:
				_drag_speed = 0.0   # the finger stopped before letting go
			if tap_closes and absf(_drag_distance) < TAP_MOVE_LIMIT:
				close()
			elif absf(_drag_speed) >= FLICK_SPEED:
				_slide_to(_drag_speed > 0.0)
			else:
				_slide_to(_open_amount >= SNAP_OPEN_FRACTION)
		return
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		accept_event()
		var now := _now()
		var elapsed := now - _last_move_time
		if elapsed > 0.0:
			_drag_speed = lerpf(_drag_speed, motion.relative.x / elapsed, SPEED_SMOOTHING)
		_last_move_time = now
		_drag_distance += motion.relative.x
		_set_open_amount(clampf(_drag_start_amount + _drag_distance / _drawer_panel.size.x, 0.0, 1.0))


## Slides the rest of the way open or shut, taking the share of SLIDE_DURATION that's left.
func _slide_to(open_it: bool) -> void:
	is_open = open_it
	_edge_swipe_area.visible = not open_it   # it would sit over the drawer's left edge
	var target := 1.0 if open_it else 0.0
	if _slide_tween:
		_slide_tween.kill()
	_slide_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_slide_tween.tween_method(_set_open_amount, _open_amount, target,
		SLIDE_DURATION * absf(target - _open_amount))


## Seconds since the engine started, to time drags.
func _now() -> float:
	return Time.get_ticks_usec() / 1e6


## Puts the drawer `amount` of the way out (0 to 1) and fades the shade beside it to match.
func _set_open_amount(amount: float) -> void:
	_open_amount = amount
	_drawer_panel.position.x = -_drawer_panel.size.x * (1.0 - amount)
	_shade_panel.modulate.a = amount
	_drawer_panel.visible = amount > 0.0
	_shade_panel.visible = amount > 0.0
