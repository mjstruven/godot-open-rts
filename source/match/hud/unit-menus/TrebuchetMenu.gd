extends GridContainer

@onready var _pack_state_btn = find_child("PackStateButton")

var units = []:
	set(value):
		units = value
		if is_node_ready():
			_refresh_pack_button()


func _ready():
	_refresh_pack_button()


func _process(_delta):
	if not visible:
		return
	_refresh_pack_button()


func _refresh_pack_button():
	if not is_instance_valid(_pack_state_btn):
		return
	var valid = units.filter(func(u): return is_instance_valid(u))
	if valid.is_empty():
		return
	var state = valid[0].get_pack_state()
	match state:
		"PACKED":
			_pack_state_btn.text = "UNP"
			_pack_state_btn.tooltip_text = "Unpack — deploy trebuchet for firing (15s) [W]"
		"UNPACKED":
			_pack_state_btn.text = "PCK"
			_pack_state_btn.tooltip_text = "Pack — fold trebuchet for movement (15s) [W]"
		_:
			_pack_state_btn.text = "CNC"
			_pack_state_btn.tooltip_text = "Cancel — reverse the current transition [W]"


func _on_pack_state_pressed():
	for u in units:
		if not is_instance_valid(u):
			continue
		u.set_pack_target(1.0 - u.get_pack_target())


func _on_attack_ground_pressed():
	MatchSignals.combat_command_requested.emit("attack_ground")
