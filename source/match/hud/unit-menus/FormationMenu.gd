extends GridContainer

const FormationGroup = preload("res://source/match/units/formations/FormationGroup.gd")

var _formation_button_group: ButtonGroup = null


func _ready():
	_formation_button_group = ButtonGroup.new()
	_formation_button_group.allow_unpress = false
	find_child("ColumnButton").button_group = _formation_button_group
	find_child("RanksButton").button_group = _formation_button_group
	find_child("BoxButton").button_group = _formation_button_group


func update_buttons():
	var fc = _fc()
	if fc == null:
		return
	var col_btn = find_child("ColumnButton")
	var rnk_btn = find_child("RanksButton")
	var box_btn = find_child("BoxButton")
	var sca_btn = find_child("ScatterButton")
	var state = fc.selection_formation_state()
	var enabled: bool = state["can_form"]
	col_btn.disabled = not enabled
	rnk_btn.disabled = not enabled
	box_btn.disabled = not enabled
	sca_btn.disabled = not enabled
	if not enabled:
		col_btn.set_pressed_no_signal(false)
		rnk_btn.set_pressed_no_signal(false)
		box_btn.set_pressed_no_signal(false)
		sca_btn.set_pressed_no_signal(false)
		return
	var ft: int = state["type"]
	col_btn.set_pressed_no_signal(ft == FormationGroup.Type.COLUMN)
	rnk_btn.set_pressed_no_signal(ft == FormationGroup.Type.RANKS)
	box_btn.set_pressed_no_signal(ft == FormationGroup.Type.BOX)
	sca_btn.set_pressed_no_signal(state["scattered"])


func _on_column_pressed():
	var fc = _fc()
	if fc != null:
		fc.set_formation_type(FormationGroup.Type.COLUMN)


func _on_box_pressed():
	var fc = _fc()
	if fc != null:
		fc.set_formation_type(FormationGroup.Type.BOX)


func _on_ranks_pressed():
	var fc = _fc()
	if fc != null:
		fc.set_formation_type(FormationGroup.Type.RANKS)


func _on_scatter_pressed():
	var fc = _fc()
	if fc != null:
		fc.set_scattered(not fc.get_scattered())


func _fc():
	var nodes = get_tree().get_nodes_in_group("formation_controller")
	return nodes[0] if not nodes.is_empty() else null
