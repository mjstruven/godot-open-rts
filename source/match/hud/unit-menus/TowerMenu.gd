extends GridContainer

var tower = null:
	set(value):
		if tower == value:
			return
		_disconnect_from_tower()
		tower = value
		_connect_to_tower()
		if is_node_ready():
			_refresh()

@onready var _occupant_buttons: Array = [
	find_child("OccupantButton1"),
	find_child("OccupantButton2"),
	find_child("OccupantButton3"),
	find_child("OccupantButton4"),
]
@onready var _eject_all_btn = find_child("EjectAllButton")


func _ready():
	if is_instance_valid(tower):
		_connect_to_tower()
	_refresh()


func _disconnect_from_tower():
	if not is_instance_valid(tower):
		return
	var gm = tower.find_child("GarrisonManager")
	if is_instance_valid(gm) and gm.garrison_changed.is_connected(_refresh):
		gm.garrison_changed.disconnect(_refresh)


func _connect_to_tower():
	if not is_instance_valid(tower):
		return
	var gm = tower.find_child("GarrisonManager")
	if is_instance_valid(gm) and not gm.garrison_changed.is_connected(_refresh):
		gm.garrison_changed.connect(_refresh)


func _refresh():
	if not is_node_ready():
		return
	var garrisoned: Array = []
	if is_instance_valid(tower):
		var gm = tower.find_child("GarrisonManager")
		if is_instance_valid(gm):
			garrisoned = gm.get_garrisoned()
	for i in range(_occupant_buttons.size()):
		var btn = _occupant_buttons[i]
		if i < garrisoned.size():
			var unit = garrisoned[i]
			btn.text = _unit_label(unit)
			btn.tooltip_text = unit.name
			btn.disabled = false
			btn.show()
		else:
			btn.text = ""
			btn.disabled = true
			btn.hide()
	_eject_all_btn.disabled = garrisoned.is_empty()


func _unit_label(unit) -> String:
	if not unit.get_script():
		return "?"
	match unit.get_script().resource_path.get_file():
		"infantry.gd":
			return "INF"
		"archer.gd":
			return "ARC"
		"ballista.gd":
			return "BAL"
		"trebuchet.gd":
			return "TRB"
	return "?"


func _eject_occupant(index: int):
	if not is_instance_valid(tower):
		return
	var gm = tower.find_child("GarrisonManager")
	if gm == null:
		return
	var garrisoned = gm.get_garrisoned()
	if index < garrisoned.size():
		gm.ungarrison_unit(garrisoned[index])


func _on_occupant_button_1_pressed():
	_eject_occupant(0)


func _on_occupant_button_2_pressed():
	_eject_occupant(1)


func _on_occupant_button_3_pressed():
	_eject_occupant(2)


func _on_occupant_button_4_pressed():
	_eject_occupant(3)


func _on_eject_all_pressed():
	if not is_instance_valid(tower):
		return
	var gm = tower.find_child("GarrisonManager")
	if gm != null:
		gm.ungarrison_all()
