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

@onready var _ungarrison_all_btn = find_child("UngarrisonAllButton")


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
	var has_any := false
	if is_instance_valid(tower):
		var gm = tower.find_child("GarrisonManager")
		if is_instance_valid(gm):
			has_any = gm.has_foot() or gm.has_siege()
	_ungarrison_all_btn.disabled = not has_any


func _on_ungarrison_all_pressed():
	if not is_instance_valid(tower):
		return
	var gm = tower.find_child("GarrisonManager")
	if gm != null:
		gm.ungarrison_all()
