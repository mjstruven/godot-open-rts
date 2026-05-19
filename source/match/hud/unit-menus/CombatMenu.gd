extends GridContainer

const Structure = preload("res://source/match/units/Structure.gd")
const ConstructingAction = preload("res://source/match/units/actions/Constructing.gd")
const AttackMoving = preload("res://source/match/units/actions/AttackMoving.gd")
const StandingGround = preload("res://source/match/units/actions/StandingGround.gd")
const Patrolling = preload("res://source/match/units/actions/Patrolling.gd")

const RALLY_TOOLTIP = (
	"Rally [F]\n"
	+ "Boost nearby allied units: +20% speed, +20% attack rate.\n"
	+ "Radius: 8 tiles. Duration: 15s. Cooldown: 45s."
)

const SUPPRESS_TOOLTIP = (
	"Suppress [S]\n"
	+ "Root archers. +2 range, +50% fire rate.\n"
	+ "Cost: 1 wood per archer per period. Duration: 25s\n"
	+ "Left-click: single use | Right-click: auto-refresh"
)

var units: Array = []:
	set(value):
		units = value
		if is_node_ready():
			_update_suppress_button()
			_update_rally_button()

@onready var _suppress_btn = find_child("SuppressButton")
@onready var _rally_btn = find_child("RallyButton")

var _rally_poll_timer: Timer = null


func _ready():
	MatchSignals.suppress_state_changed.connect(_on_suppress_state_changed)
	_suppress_btn.gui_input.connect(_on_suppress_gui_input)
	_update_suppress_button()
	_update_rally_button()

	_rally_poll_timer = Timer.new()
	_rally_poll_timer.wait_time = 0.5
	_rally_poll_timer.timeout.connect(_update_rally_button)
	add_child(_rally_poll_timer)
	_rally_poll_timer.start()


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
			_handle_suppress_click(false)
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
		_handle_suppress_click(false)
		_suppress_btn.get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_suppress_click(true)
		_suppress_btn.get_viewport().set_input_as_handled()


func _handle_suppress_click(auto_refresh: bool):
	var archers = _get_archers()
	if archers.is_empty():
		return

	var any_active = archers.any(func(a):
		return a.is_in_group("suppress_armed") or a.is_in_group("suppressing")
	)
	if any_active:
		_cancel_suppress(archers)
		return

	if not archers[0].player.has_resources({"wood": archers.size()}):
		_update_suppress_button()
		return

	var mode = "toggle" if auto_refresh else "single"
	GameLogger.info(GameLogger.Category.COMBAT, "Suppress activated", {
		"archer_count": archers.size(),
		"mode": mode,
		"wood_cost": archers.size()
	})

	for archer in archers:
		archer.add_to_group("suppress_armed")
		archer.set_meta("suppress_auto_refresh", auto_refresh)
		MatchSignals.suppress_state_changed.emit(archer, "armed", auto_refresh)


func _cancel_suppress(archers: Array):
	for archer in archers:
		archer.remove_from_group("suppress_armed")
		archer.action = null


func _get_archers() -> Array:
	return units.filter(func(u): return is_instance_valid(u) and u.type == "archer")


func _on_suppress_state_changed(unit, _state, _auto_refresh):
	if unit in units:
		_update_suppress_button()


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
	var auto_mode = archers.any(func(a): return a.get_meta("suppress_auto_refresh", false))

	if any_suppressing or any_armed:
		if auto_mode:
			_suppress_btn.modulate = Color(0.3, 0.8, 1.0)
			_suppress_btn.text = "SP~"
			_suppress_btn.tooltip_text = "Suppress ACTIVE (auto-refresh)\nLeft-click or [S] to cancel"
		else:
			_suppress_btn.modulate = Color(1.0, 0.8, 0.2)
			_suppress_btn.text = "SP!"
			_suppress_btn.tooltip_text = "Suppress ACTIVE (single use)\nLeft-click or [S] to cancel"
	elif not archers[0].player.has_resources({"wood": archers.size()}):
		_suppress_btn.modulate = Color(1.0, 0.3, 0.3)
		_suppress_btn.text = "SP"
		_suppress_btn.tooltip_text = "Suppress — Insufficient wood (need %d)" % archers.size()
	else:
		_suppress_btn.modulate = Color.WHITE
		_suppress_btn.text = "SP"
		_suppress_btn.tooltip_text = SUPPRESS_TOOLTIP
