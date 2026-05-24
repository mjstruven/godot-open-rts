extends GridContainer

const INFANTRY_PATH = "res://source/match/units/infantry.tscn"
const ARCHER_PATH = "res://source/match/units/archer.tscn"
const CAVALRY_PATH = "res://source/match/units/cavalry.tscn"

var units = []:
	set(new_units):
		_disconnect_units()
		units = new_units
		_connect_units()
		_refresh_buttons()

@onready var _btn_infantry: Button = $InfantryButton
@onready var _btn_archer: Button = $ArcherButton
@onready var _btn_cavalry: Button = $CavalryButton


func _disconnect_units():
	for u in units:
		if not is_instance_valid(u) or u.production_toggle == null:
			continue
		if u.production_toggle.toggled.is_connected(_on_unit_toggled):
			u.production_toggle.toggled.disconnect(_on_unit_toggled)


func _connect_units():
	for u in units:
		if u.production_toggle != null:
			u.production_toggle.toggled.connect(_on_unit_toggled)


func _on_unit_toggled(_path: String):
	_refresh_buttons()


func _refresh_buttons():
	var active = _get_active_path()
	_btn_infantry.set_pressed_no_signal(active == INFANTRY_PATH)
	_btn_archer.set_pressed_no_signal(active == ARCHER_PATH)
	_btn_cavalry.set_pressed_no_signal(active == CAVALRY_PATH)


func _get_active_path() -> String:
	for u in units:
		if is_instance_valid(u) and u.production_toggle != null:
			return u.production_toggle.active_scene_path
	return ""


func _on_infantry_button_toggled(pressed: bool):
	_apply_toggle(INFANTRY_PATH if pressed else "")


func _on_archer_button_toggled(pressed: bool):
	_apply_toggle(ARCHER_PATH if pressed else "")


func _on_cavalry_button_toggled(pressed: bool):
	_apply_toggle(CAVALRY_PATH if pressed else "")


func _on_stop_button_pressed():
	_apply_toggle("")


func _apply_toggle(scene_path: String):
	for u in units:
		if not is_instance_valid(u) or not u.is_constructed() or u.production_toggle == null:
			continue
		if scene_path.is_empty():
			u.production_toggle.stop()
		elif u.production_toggle.active_scene_path != scene_path:
			u.production_toggle.toggle(scene_path)
	_refresh_buttons()
