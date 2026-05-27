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
@onready var _ungarrison_foot_btn = find_child("UngarrisonFootButton")
@onready var _ungarrison_siege_btn = find_child("UngarrisonSiegeButton")


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
	var has_foot := false
	var has_siege := false
	if is_instance_valid(tower):
		var gm = tower.find_child("GarrisonManager")
		if is_instance_valid(gm):
			has_foot = gm.has_foot()
			has_siege = gm.has_siege()
	_ungarrison_all_btn.disabled = not has_foot and not has_siege
	_ungarrison_foot_btn.disabled = not has_foot
	_ungarrison_siege_btn.disabled = not has_siege


func _on_ungarrison_all_pressed():
	if not is_instance_valid(tower):
		return
	var gm = tower.find_child("GarrisonManager")
	if gm != null:
		gm.ungarrison_all()


func _on_ungarrison_foot_pressed():
	if not is_instance_valid(tower):
		return
	var gm = tower.find_child("GarrisonManager")
	if gm != null:
		gm.ungarrison_foot_only()


func _on_ungarrison_siege_pressed():
	if not is_instance_valid(tower):
		return
	var gm = tower.find_child("GarrisonManager")
	if gm != null:
		gm.ungarrison_siege_only()
