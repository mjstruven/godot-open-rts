extends GridContainer

var units: Array = []
var _counter_label: Label = null


func _ready():
	var btn = get_node("ChargeButton")
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
	var cavalry = units.filter(func(u): return u.get("type") == "cavalry")
	var ready_count = cavalry.filter(func(u): return _is_charge_ready(u)).size()
	get_node("ChargeButton").disabled = ready_count == 0
	_counter_label.text = "%d/%d" % [ready_count, cavalry.size()]


func _handle_charge_click():
	MatchSignals.combat_command_requested.emit("charge")


func _is_charge_ready(unit) -> bool:
	return (
		not unit.has_meta("charge_cooldown_end_ms")
		or Time.get_ticks_msec() >= unit.get_meta("charge_cooldown_end_ms")
	)
