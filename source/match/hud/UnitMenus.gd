extends PanelContainer

const Structure = preload("res://source/match/units/Structure.gd")

@onready var _generic_menu = find_child("GenericMenu")
@onready var _combat_menu = find_child("CombatMenu")
@onready var _formation_menu = find_child("FormationMenu")

const _CELL_KEYS = {
	KEY_Q: 0, KEY_W: 1, KEY_E: 2, KEY_R: 3,
	KEY_A: 4, KEY_S: 5, KEY_D: 6, KEY_F: 7,
	KEY_Z: 8, KEY_X: 9, KEY_C: 10, KEY_V: 11
}

const _ORDER_LABELS = [
	"Ctrl-Q", "Ctrl-W", "Ctrl-E", "Ctrl-R",
	"Ctrl-A", "Ctrl-S", "Ctrl-D", "Ctrl-F",
	"Ctrl-Z", "Ctrl-X", "Ctrl-C", "Ctrl-V"
]

var _focused_units: Array = []


func _ready():
	_reset_menus()
	MatchSignals.unit_focus_changed.connect(_on_unit_focus_changed)
	MatchSignals.formation_changed.connect(func(): _reset_menus())
	_stamp_order_labels()


func _on_unit_focus_changed(focused_controlled_units: Array):
	_focused_units = focused_controlled_units
	_reset_menus()


func _reset_menus():
	_hide_all_menus()
	_try_showing_any_menu()


func _stamp_order_labels() -> void:
	for grid in [_combat_menu, _generic_menu, _formation_menu]:
		_stamp_grid_labels(grid, _ORDER_LABELS)


func _stamp_grid_labels(grid: Node, labels: Array) -> void:
	for i in range(mini(12, grid.get_child_count())):
		var child = grid.get_child(i)
		if not child is Button:
			continue
		var lbl = Label.new()
		lbl.text = labels[i]
		lbl.layout_mode = 1
		lbl.anchor_left = 1.0
		lbl.anchor_top = 1.0
		lbl.anchor_right = 1.0
		lbl.anchor_bottom = 1.0
		lbl.offset_left = -46.0
		lbl.offset_top = -12.0
		lbl.offset_right = -2.0
		lbl.offset_bottom = -2.0
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.modulate = Color(0.75, 0.75, 0.75, 0.85)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		child.add_child(lbl)


func _hide_all_menus():
	_generic_menu.hide()
	_combat_menu.hide()
	_formation_menu.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed:
		return
	var cell_index = _CELL_KEYS.get(event.keycode, -1)
	if cell_index < 0:
		return
	var btn = _get_orders_cell_button(cell_index)
	if btn == null or btn.disabled:
		return
	btn.pressed.emit()
	get_viewport().set_input_as_handled()


func _get_orders_cell_button(cell_index: int) -> Button:
	if _combat_menu.visible:
		for grid in [_combat_menu, _formation_menu]:
			if not grid.visible:
				continue
			if cell_index >= grid.get_child_count():
				continue
			var node = grid.get_child(cell_index)
			if node is Button:
				return node
		return null
	if _generic_menu.visible:
		if cell_index >= _generic_menu.get_child_count():
			return null
		var node = _generic_menu.get_child(cell_index)
		return node if node is Button else null
	return null


func _try_showing_any_menu():
	var selected = _focused_units.filter(func(u): return is_instance_valid(u))
	var combat_units = selected.filter(
		func(u): return u.attack_range != null and not u is Structure
	)
	if not combat_units.is_empty():
		_combat_menu.units = selected
		_combat_menu.show()
		_formation_menu.update_buttons()
		_formation_menu.show()
		return
	if selected.size() > 0:
		_generic_menu.units = selected
		_generic_menu.show()
