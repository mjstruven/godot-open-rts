extends PanelContainer

const TYPE_ORDER = [
	"flag_commander", "infantry", "archer", "cavalry",
	"ballista", "battering_ram", "siege_tower", "trebuchet", "engineer"
]

var _selected_units: Array = []
var _type_list: Array = []
var _focused_index: int = 0
var _narrowing: bool = false

@onready var _buttons_box = find_child("TypeButtonsContainer")


func _ready():
	MatchSignals.unit_selected.connect(_on_unit_selected)
	MatchSignals.unit_deselected.connect(_on_unit_deselected)
	MatchSignals.unit_died.connect(_on_unit_died)
	hide()


func _unhandled_input(event):
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_TAB:
		if event.ctrl_pressed:
			_narrow_selection_to_focused_type()
		elif event.shift_pressed:
			_cycle_focused_type_backward()
		else:
			_cycle_focused_type()
		get_viewport().set_input_as_handled()


func _on_unit_selected(unit):
	if unit not in _selected_units:
		_selected_units.append(unit)
	_focused_index = 0
	_rebuild()


func _on_unit_deselected(unit):
	_selected_units.erase(unit)
	if _narrowing:
		return
	_focused_index = 0
	_rebuild()


func _on_unit_died(unit):
	_selected_units.erase(unit)
	if _narrowing:
		return
	_focused_index = mini(_focused_index, max(0, _type_list.size() - 1))
	_rebuild()


func _rebuild():
	_selected_units = _selected_units.filter(func(u): return is_instance_valid(u))
	_type_list = _build_sorted_type_list()
	if _type_list.is_empty():
		hide()
		MatchSignals.unit_focus_changed.emit([])
		return
	_focused_index = clampi(_focused_index, 0, _type_list.size() - 1)
	_rebuild_buttons()
	show()
	_emit_focus()


func _build_sorted_type_list() -> Array:
	var counts = {}
	for u in _selected_units:
		var t = u.type
		if t not in counts:
			counts[t] = 0
		counts[t] += 1
	var types = counts.keys()
	types.sort_custom(func(a, b):
		var ai = TYPE_ORDER.find(a)
		var bi = TYPE_ORDER.find(b)
		if ai == -1:
			ai = TYPE_ORDER.size()
		if bi == -1:
			bi = TYPE_ORDER.size()
		if ai != bi:
			return ai < bi
		return a < b
	)
	return types


func _rebuild_buttons():
	for child in _buttons_box.get_children():
		_buttons_box.remove_child(child)
		child.queue_free()
	for i in range(_type_list.size()):
		var t = _type_list[i]
		var count = _selected_units.filter(func(u): return is_instance_valid(u) and u.type == t).size()
		var btn = Button.new()
		btn.text = "%s\nx%d" % [_abbrev(t), count] if count > 1 else _abbrev(t)
		btn.custom_minimum_size = Vector2(48, 48)
		btn.focus_mode = Control.FOCUS_NONE
		if i == _focused_index:
			btn.modulate = Color(1.2, 1.1, 0.5)
		var captured_i = i
		btn.pressed.connect(func(): _on_button_pressed(captured_i))
		_buttons_box.add_child(btn)


func _abbrev(type_name: String) -> String:
	match type_name:
		"flag_commander": return "CMD"
		"infantry": return "INF"
		"archer": return "ARC"
		"cavalry": return "CAV"
		"ballista": return "BAL"
		"battering_ram": return "RAM"
		"siege_tower": return "TWR"
		"trebuchet": return "TRB"
		"engineer": return "ENG"
		_: return type_name.substr(0, 3).to_upper()


func _on_button_pressed(index: int):
	if index == _focused_index:
		return
	_focused_index = index
	_rebuild_buttons()
	_emit_focus()


func _cycle_focused_type():
	if _type_list.size() <= 1:
		return
	_focused_index = (_focused_index + 1) % _type_list.size()
	_rebuild_buttons()
	_emit_focus()


func _cycle_focused_type_backward():
	if _type_list.size() <= 1:
		return
	_focused_index = (_focused_index - 1 + _type_list.size()) % _type_list.size()
	_rebuild_buttons()
	_emit_focus()


func _narrow_selection_to_focused_type():
	if _type_list.is_empty():
		return
	var focused_type = _type_list[_focused_index]
	var to_deselect = _selected_units.filter(
		func(u): return is_instance_valid(u) and u.type != focused_type
	).duplicate()
	if to_deselect.is_empty():
		return
	_narrowing = true
	for u in to_deselect:
		if u.is_in_group("selected_units"):
			u.remove_from_group("selected_units")
			MatchSignals.unit_deselected.emit(u)
	_narrowing = false
	_focused_index = 0
	_rebuild()


func _emit_focus():
	if _type_list.is_empty():
		MatchSignals.unit_focus_changed.emit([])
		return
	var ft = _type_list[_focused_index]
	var units = _selected_units.filter(
		func(u): return is_instance_valid(u) and u.type == ft and u.is_in_group("controlled_units")
	)
	MatchSignals.unit_focus_changed.emit(units)
