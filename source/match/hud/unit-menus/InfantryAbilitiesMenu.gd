extends GridContainer

var units: Array = []
var _counter_label: Label = null


func _ready():
	var btn = get_node("BolsterButton")
	_counter_label = Label.new()
	_counter_label.layout_mode = 1
	_counter_label.anchor_left = 0.0
	_counter_label.anchor_top = 0.0
	_counter_label.anchor_right = 0.0
	_counter_label.anchor_bottom = 0.0
	_counter_label.offset_left = 2.0
	_counter_label.offset_top = 2.0
	_counter_label.offset_right = 24.0
	_counter_label.offset_bottom = 12.0
	_counter_label.add_theme_font_size_override("font_size", 8)
	_counter_label.modulate = Color(0.75, 0.75, 0.75, 0.85)
	_counter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_child(_counter_label)


func _process(_delta):
	if not visible:
		return
	var infantry = units.filter(func(u): return is_instance_valid(u) and u.get("type") == "infantry")
	var any_bolstering = infantry.any(func(u): return u.is_in_group("bolstering"))
	var ready_count = infantry.filter(
		func(u): return _is_bolster_ready(u) and not u.is_in_group("bolstering")
	).size()
	var btn = get_node("BolsterButton")
	if any_bolstering:
		btn.text = "CNCL"
		btn.tooltip_text = "Cancel Bolster"
	else:
		btn.text = "BLT"
		btn.tooltip_text = "Bolster"
	_counter_label.text = "%d/%d" % [ready_count, infantry.size()]
	btn.disabled = ready_count == 0 and not any_bolstering


func _handle_bolster_click():
	var infantry = units.filter(func(u): return is_instance_valid(u) and u.get("type") == "infantry")
	var any_bolstering = infantry.any(func(u): return u.is_in_group("bolstering"))
	if any_bolstering:
		MatchSignals.combat_command_requested.emit("cancel_bolster")
	else:
		MatchSignals.combat_command_requested.emit("bolster")


func _is_bolster_ready(unit) -> bool:
	return (
		not unit.has_meta("bolster_cooldown_end_ms")
		or Time.get_ticks_msec() >= unit.get_meta("bolster_cooldown_end_ms")
	)
