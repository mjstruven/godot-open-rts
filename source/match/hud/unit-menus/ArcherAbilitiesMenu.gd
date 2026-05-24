extends GridContainer

const SuppressedAttackingScript = preload(
	"res://source/match/units/actions/SuppressedAttacking.gd"
)
const Circle3D = preload("res://source/generic-scenes-and-nodes/3d/Circle3D.gd")

const SUPPRESS_TOOLTIP = (
	"Suppress [S]\n"
	+ "Root archers. +2 range, +50% fire rate.\n"
	+ "Cost: 1 wood per archer. Toggle: press again to cancel.\n"
	+ "Cooldown: 5s after deactivation. Hover to preview range."
)

var units: Array = []:
	set(value):
		units = value
		if is_node_ready():
			_hide_range_preview()
			_update_suppress_button()

@onready var _suppress_btn = find_child("SuppressButton")

var _range_preview_circles: Array = []
var _range_preview_archer_refs: Array = []
var _suppress_active_style: StyleBoxFlat = null
var _poll_timer: Timer = null


func _ready():
	_suppress_active_style = StyleBoxFlat.new()
	_suppress_active_style.border_color = Color(0.2, 0.85, 0.2)
	_suppress_active_style.set_border_width_all(2)
	_suppress_active_style.bg_color = Color(0.25, 0.25, 0.25, 1.0)
	_suppress_active_style.corner_radius_top_left = 4
	_suppress_active_style.corner_radius_top_right = 4
	_suppress_active_style.corner_radius_bottom_left = 4
	_suppress_active_style.corner_radius_bottom_right = 4

	MatchSignals.suppress_state_changed.connect(_on_suppress_state_changed)
	_suppress_btn.gui_input.connect(_on_suppress_gui_input)
	_suppress_btn.mouse_entered.connect(_on_suppress_btn_mouse_entered)
	_suppress_btn.mouse_exited.connect(_on_suppress_btn_mouse_exited)

	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.5
	_poll_timer.timeout.connect(_update_suppress_button)
	add_child(_poll_timer)
	_poll_timer.start()

	_update_suppress_button()


func _process(_delta):
	for i in range(_range_preview_archer_refs.size()):
		var archer = _range_preview_archer_refs[i]
		var circle = _range_preview_circles[i]
		if is_instance_valid(archer) and is_instance_valid(circle):
			circle.global_position = Vector3(archer.global_position.x, 0.01, archer.global_position.z)


func _unhandled_input(event):
	if not is_visible_in_tree():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_S:
		_handle_suppress_click()
		get_viewport().set_input_as_handled()


func _get_archers() -> Array:
	return units.filter(func(u): return is_instance_valid(u) and u.type == "archer")


func _handle_suppress_click():
	var archers = _get_archers()
	if archers.is_empty():
		return
	var any_active = archers.any(func(a):
		return a.is_in_group("suppress_armed") or a.is_in_group("suppressing")
	)
	if any_active:
		_cancel_suppress(archers)
		return
	if _is_any_archer_on_cooldown(archers):
		return
	if not archers[0].player.has_resources({"wood": archers.size()}):
		_update_suppress_button()
		return
	for archer in archers:
		archer.action_queue.clear()
		archer.action = null
		var movement = archer.find_child("Movement")
		if movement:
			movement.stop()
		archer.add_to_group("suppress_armed")
		MatchSignals.suppress_state_changed.emit(archer, "armed")


func _cancel_suppress(archers: Array):
	for archer in archers:
		archer.remove_from_group("suppress_armed")
		archer.action = null


func _is_any_archer_on_cooldown(archers: Array) -> bool:
	var now = Time.get_ticks_msec()
	return archers.any(func(a):
		return a.has_meta("suppress_cooldown_until_ms") and now < a.get_meta("suppress_cooldown_until_ms")
	)


func _on_suppress_gui_input(event: InputEvent):
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_handle_suppress_click()
		_suppress_btn.get_viewport().set_input_as_handled()


func _on_suppress_state_changed(unit, _state):
	if unit in units:
		_update_suppress_button()


func _update_suppress_button():
	if not is_instance_valid(_suppress_btn):
		return
	var archers = _get_archers()
	if archers.is_empty():
		_suppress_btn.disabled = true
		_suppress_btn.modulate = Color(0.7, 0.7, 0.7)
		_suppress_btn.remove_theme_stylebox_override("normal")
		_suppress_btn.tooltip_text = "Suppress (no archers selected)"
		return
	_suppress_btn.disabled = false
	var any_suppressing = archers.any(func(a): return a.is_in_group("suppressing"))
	var any_armed = archers.any(func(a): return a.is_in_group("suppress_armed"))
	if any_suppressing or any_armed:
		_suppress_btn.modulate = Color.WHITE
		_suppress_btn.text = "SP!"
		_suppress_btn.add_theme_stylebox_override("normal", _suppress_active_style)
		_suppress_btn.tooltip_text = "Suppress ACTIVE\nLeft-click or [S] to cancel"
	elif _is_any_archer_on_cooldown(archers):
		_suppress_btn.disabled = true
		_suppress_btn.modulate = Color(0.7, 0.7, 0.7)
		_suppress_btn.text = "SP"
		_suppress_btn.remove_theme_stylebox_override("normal")
		_suppress_btn.tooltip_text = "Suppress on cooldown (%ds)" % SuppressedAttackingScript.COOLDOWN_DURATION
	elif not archers[0].player.has_resources({"wood": archers.size()}):
		_suppress_btn.modulate = Color(1.0, 0.3, 0.3)
		_suppress_btn.text = "SP"
		_suppress_btn.remove_theme_stylebox_override("normal")
		_suppress_btn.tooltip_text = "Suppress — Insufficient wood (need %d)" % archers.size()
	else:
		_suppress_btn.modulate = Color.WHITE
		_suppress_btn.text = "SP"
		_suppress_btn.remove_theme_stylebox_override("normal")
		_suppress_btn.tooltip_text = SUPPRESS_TOOLTIP


func _on_suppress_btn_mouse_entered():
	_show_range_preview()


func _on_suppress_btn_mouse_exited():
	_hide_range_preview()


func _show_range_preview():
	_hide_range_preview()
	var archers = _get_archers()
	if archers.is_empty():
		return
	var match_node = find_parent("Match")
	if match_node == null:
		return
	for archer in archers:
		if not is_instance_valid(archer):
			continue
		var circle = Circle3D.new()
		circle.radius = archer.attack_range + SuppressedAttackingScript.RANGE_BONUS
		circle.width = 4.0
		circle.color = Color(0.6, 0.6, 0.6, 0.5)
		match_node.add_child(circle)
		circle.global_position = Vector3(archer.global_position.x, 0.01, archer.global_position.z)
		_range_preview_circles.append(circle)
		_range_preview_archer_refs.append(archer)


func _hide_range_preview():
	for c in _range_preview_circles:
		if is_instance_valid(c):
			c.queue_free()
	_range_preview_circles.clear()
	_range_preview_archer_refs.clear()
