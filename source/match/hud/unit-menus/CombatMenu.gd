extends GridContainer

const Structure = preload("res://source/match/units/Structure.gd")
const ConstructingAction = preload("res://source/match/units/actions/Constructing.gd")
const AttackMoving = preload("res://source/match/units/actions/AttackMoving.gd")
const StandingGround = preload("res://source/match/units/actions/StandingGround.gd")
const Patrolling = preload("res://source/match/units/actions/Patrolling.gd")
const SuppressedAttackingScript = preload(
	"res://source/match/units/actions/SuppressedAttacking.gd"
)
const Circle3D = preload("res://source/generic-scenes-and-nodes/3d/Circle3D.gd")

const RALLY_TOOLTIP = (
	"Rally [F]\n"
	+ "Boost nearby allied units: +20% speed, +20% attack rate.\n"
	+ "Radius: 8 tiles. Duration: 15s. Cooldown: 45s."
)

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
			_update_rally_button()
			_update_dismiss_button()

@onready var _suppress_btn = find_child("SuppressButton")
@onready var _rally_btn = find_child("RallyButton")
@onready var _dismiss_btn = find_child("DismissButton")

var _rally_poll_timer: Timer = null
var _range_preview_circles: Array = []


func _ready():
	MatchSignals.suppress_state_changed.connect(_on_suppress_state_changed)
	_suppress_btn.gui_input.connect(_on_suppress_gui_input)
	_suppress_btn.mouse_entered.connect(_on_suppress_btn_mouse_entered)
	_suppress_btn.mouse_exited.connect(_on_suppress_btn_mouse_exited)
	_update_suppress_button()
	_update_rally_button()

	_rally_poll_timer = Timer.new()
	_rally_poll_timer.wait_time = 0.5
	_rally_poll_timer.timeout.connect(_update_rally_button)
	_rally_poll_timer.timeout.connect(_update_dismiss_button)
	_rally_poll_timer.timeout.connect(_update_suppress_button)
	add_child(_rally_poll_timer)
	_rally_poll_timer.start()
	_update_dismiss_button()


func _unhandled_input(event):
	if not is_visible_in_tree():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_Q:
			_on_attack_move_pressed()
			get_viewport().set_input_as_handled()
		KEY_W:
			_on_patrol_pressed()
			get_viewport().set_input_as_handled()
		KEY_E:
			_on_stand_ground_pressed()
			get_viewport().set_input_as_handled()
		KEY_R:
			_on_capture_pressed()
			get_viewport().set_input_as_handled()
		KEY_S:
			_handle_suppress_click()
			get_viewport().set_input_as_handled()
		KEY_F:
			_handle_rally_click()
			get_viewport().set_input_as_handled()


func _on_attack_move_pressed():
	MatchSignals.combat_command_requested.emit("attack_move")


func _on_patrol_pressed():
	MatchSignals.combat_command_requested.emit("patrol")


func _on_stand_ground_pressed():
	MatchSignals.combat_command_requested.emit("stand_ground")


func _on_capture_pressed():
	pass  # placeholder for future capture mechanic


func _handle_rally_click():
	var fcs = _get_flag_commanders()
	if fcs.is_empty():
		return
	for fc in fcs:
		var ability = fc.find_child("RallyAbility")
		if ability != null and ability.is_ready():
			ability.activate()
			break
	_update_rally_button()


func _get_flag_commanders() -> Array:
	return units.filter(func(u): return is_instance_valid(u) and u.type == "flag_commander")


func _update_rally_button():
	if not is_instance_valid(_rally_btn):
		return
	var fcs = _get_flag_commanders()
	if fcs.is_empty():
		_rally_btn.disabled = true
		_rally_btn.modulate = Color(0.5, 0.5, 0.5)
		_rally_btn.tooltip_text = "Rally (no Flag Commander selected)"
		return

	_rally_btn.disabled = false
	var fc = fcs[0]
	var ability = fc.find_child("RallyAbility")
	if ability == null or ability.is_ready():
		_rally_btn.modulate = Color.WHITE
		_rally_btn.tooltip_text = RALLY_TOOLTIP
	else:
		var remaining = int(ceil(ability.get_cooldown_remaining()))
		_rally_btn.modulate = Color(0.5, 0.5, 0.5)
		_rally_btn.tooltip_text = "Rally on cooldown (%ds)" % remaining


func _on_cancel_button_pressed():
	for unit in units:
		if not is_instance_valid(unit):
			continue
		if unit.action is ConstructingAction:
			continue
		unit.action = null


func _on_suppress_gui_input(event: InputEvent):
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_handle_suppress_click()
		_suppress_btn.get_viewport().set_input_as_handled()


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

	GameLogger.info(GameLogger.Category.COMBAT, "Suppress activated", {
		"archer_count": archers.size(),
		"wood_cost": archers.size()
	})

	for archer in archers:
		archer.add_to_group("suppress_armed")
		MatchSignals.suppress_state_changed.emit(archer, "armed")


func _cancel_suppress(archers: Array):
	for archer in archers:
		archer.remove_from_group("suppress_armed")
		archer.action = null


func _get_archers() -> Array:
	return units.filter(func(u): return is_instance_valid(u) and u.type == "archer")


func _is_any_archer_on_cooldown(archers: Array) -> bool:
	var now = Time.get_ticks_msec()
	return archers.any(func(a):
		return a.has_meta("suppress_cooldown_until_ms") and now < a.get_meta("suppress_cooldown_until_ms")
	)


func _on_suppress_state_changed(unit, _state):
	if unit in units:
		_update_suppress_button()


func _get_dismissible_units() -> Array:
	return units.filter(func(u): return is_instance_valid(u) and u.find_child("Dismiss") != null)


func _on_dismiss_pressed():
	var dismissible = _get_dismissible_units()
	if dismissible.is_empty():
		return
	var any_dismissing = dismissible.any(func(u):
		var d = u.find_child("Dismiss")
		return d != null and d.is_dismissing()
	)
	if any_dismissing:
		for u in dismissible:
			var d = u.find_child("Dismiss")
			if d != null:
				d.cancel_dismiss()
	else:
		for u in dismissible:
			var d = u.find_child("Dismiss")
			if d != null:
				d.start_dismiss()
	_update_dismiss_button()


func _update_dismiss_button():
	if not is_instance_valid(_dismiss_btn):
		return
	var dismissible = _get_dismissible_units()
	if dismissible.is_empty():
		_dismiss_btn.disabled = true
		_dismiss_btn.modulate = Color(0.5, 0.5, 0.5)
		_dismiss_btn.tooltip_text = "Dismiss (no dismissible units selected)"
		return
	var any_dismissing = dismissible.any(func(u):
		var d = u.find_child("Dismiss")
		return d != null and d.is_dismissing()
	)
	var any_blocked = dismissible.any(func(u):
		var d = u.find_child("Dismiss")
		return d != null and d.has_cooldown()
	)
	if any_blocked and not any_dismissing:
		_dismiss_btn.disabled = true
		_dismiss_btn.modulate = Color(0.5, 0.5, 0.5)
		_dismiss_btn.tooltip_text = "Dismiss on cooldown (60s from first press)"
	elif any_dismissing:
		_dismiss_btn.disabled = false
		_dismiss_btn.modulate = Color(1.0, 0.5, 0.2)
		_dismiss_btn.tooltip_text = "Dismiss in progress — press to cancel"
	else:
		_dismiss_btn.disabled = false
		_dismiss_btn.modulate = Color.WHITE
		_dismiss_btn.tooltip_text = "Dismiss unit(s) — 15s countdown, then civilians spawn"


func _update_suppress_button():
	var archers = _get_archers()
	if archers.is_empty():
		_suppress_btn.disabled = true
		_suppress_btn.modulate = Color(0.5, 0.5, 0.5)
		_suppress_btn.tooltip_text = "Suppress (no archers selected)"
		return

	_suppress_btn.disabled = false

	var any_suppressing = archers.any(func(a): return a.is_in_group("suppressing"))
	var any_armed = archers.any(func(a): return a.is_in_group("suppress_armed"))

	if any_suppressing or any_armed:
		_suppress_btn.modulate = Color(1.0, 0.8, 0.2)
		_suppress_btn.text = "SP!"
		_suppress_btn.tooltip_text = "Suppress ACTIVE\nLeft-click or [S] to cancel"
	elif _is_any_archer_on_cooldown(archers):
		_suppress_btn.disabled = true
		_suppress_btn.modulate = Color(0.5, 0.5, 0.5)
		_suppress_btn.text = "SP"
		_suppress_btn.tooltip_text = "Suppress on cooldown (%ds)" % SuppressedAttackingScript.COOLDOWN_DURATION
	elif not archers[0].player.has_resources({"wood": archers.size()}):
		_suppress_btn.modulate = Color(1.0, 0.3, 0.3)
		_suppress_btn.text = "SP"
		_suppress_btn.tooltip_text = "Suppress — Insufficient wood (need %d)" % archers.size()
	else:
		_suppress_btn.modulate = Color.WHITE
		_suppress_btn.text = "SP"
		_suppress_btn.tooltip_text = SUPPRESS_TOOLTIP


# ── Hover range preview ──────────────────────────────────────────────────────

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


func _hide_range_preview():
	for c in _range_preview_circles:
		if is_instance_valid(c):
			c.queue_free()
	_range_preview_circles.clear()
