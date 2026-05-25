extends GridContainer

var units: Array = []
var _counter_label: Label = null
var _cancel_btn: Button = null


func _ready():
	var btn = get_node("BolsterButton")
	_counter_label = Label.new()
	_counter_label.position = Vector2(2.0, 2.0)
	_counter_label.size = Vector2(22.0, 10.0)
	_counter_label.add_theme_font_size_override("font_size", 8)
	_counter_label.modulate = Color(0.75, 0.75, 0.75, 0.85)
	_counter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_child(_counter_label)
	_cancel_btn = get_node("CancelButton")
	_cancel_btn.pressed.connect(_handle_cancel_click)


func _process(_delta):
	if not visible:
		return
	var infantry = units.filter(func(u): return is_instance_valid(u) and u.get("type") == "infantry")
	var bolstering = infantry.filter(func(u): return u.is_in_group("bolstering"))
	var non_bolstering = infantry.filter(func(u): return not u.is_in_group("bolstering"))
	var is_mixed = bolstering.size() > 0 and non_bolstering.size() > 0
	var ready_count = non_bolstering.filter(func(u): return _is_bolster_ready(u)).size()

	var btn = get_node("BolsterButton")
	var pad2 = get_node("Pad2")

	if is_mixed:
		pad2.visible = false
		_cancel_btn.visible = true
		_cancel_btn.disabled = false
		btn.text = "BLT"
		btn.tooltip_text = "Bolster"
		btn.disabled = ready_count == 0
	else:
		pad2.visible = true
		_cancel_btn.visible = false
		_cancel_btn.disabled = true
		if bolstering.is_empty():
			btn.text = "BLT"
			btn.tooltip_text = "Bolster"
			btn.disabled = ready_count == 0
		else:
			btn.text = "CNCL"
			btn.tooltip_text = "Cancel Bolster"
			btn.disabled = false

	_counter_label.text = "%d/%d" % [ready_count, infantry.size()]


func _handle_bolster_click():
	var infantry = units.filter(func(u): return is_instance_valid(u) and u.get("type") == "infantry")
	var all_bolstering = infantry.all(func(u): return u.is_in_group("bolstering"))
	if all_bolstering:
		MatchSignals.combat_command_requested.emit("cancel_bolster")
	else:
		MatchSignals.combat_command_requested.emit("bolster")


func _handle_cancel_click():
	MatchSignals.combat_command_requested.emit("cancel_bolster")


func _is_bolster_ready(unit) -> bool:
	return (
		not unit.has_meta("bolster_cooldown_end_ms")
		or Time.get_ticks_msec() >= unit.get_meta("bolster_cooldown_end_ms")
	)
