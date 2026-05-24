extends GridContainer

const ConstructingAction = preload("res://source/match/units/actions/Constructing.gd")

@onready var _dismiss_btn = find_child("DismissButton")

var units = []:
	set(value):
		units = value
		if is_node_ready():
			_update_dismiss_button()

var _poll_timer: Timer = null


func _ready():
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.5
	_poll_timer.timeout.connect(_update_dismiss_button)
	add_child(_poll_timer)
	_poll_timer.start()
	_update_dismiss_button()


func _on_cancel_action_button_pressed():
	for unit in units:
		if not is_instance_valid(unit):
			continue
		if unit.action is ConstructingAction:
			continue
		unit.action = null


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
