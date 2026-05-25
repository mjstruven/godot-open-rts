extends GridContainer

const FormationGroup = preload("res://source/match/units/formations/FormationGroup.gd")


func update_buttons():
	var fc = _fc()
	if fc == null:
		return
	var ft = fc.get_formation_type()
	find_child("ColumnButton").set_pressed_no_signal(ft == FormationGroup.Type.COLUMN)
	find_child("BoxButton").set_pressed_no_signal(ft == FormationGroup.Type.BOX)
	find_child("RanksButton").set_pressed_no_signal(ft == FormationGroup.Type.RANKS)
	find_child("ScatterButton").set_pressed_no_signal(fc.get_scattered())


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
