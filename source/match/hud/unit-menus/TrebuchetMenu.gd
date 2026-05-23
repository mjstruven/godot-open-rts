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
			_pack_state_btn.text = "UNPACK"
			_pack_state_btn.tooltip_text = "Unpack — deploy trebuchet for firing (15s) [W]"
		"UNPACKED":
			_pack_state_btn.text = "PACK"
			_pack_state_btn.tooltip_text = "Pack — fold trebuchet for movement (15s) [W]"
		_:
			_pack_state_btn.text = "CANCEL"
			_pack_state_btn.tooltip_text = "Cancel — reverse the current transition [W]"


func _unhandled_input(event):
	if not is_visible_in_tree():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_Q:
		_on_abandon_pressed()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_W:
		_on_pack_state_pressed()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_E:
		_on_attack_ground_pressed()
		get_viewport().set_input_as_handled()


func _on_abandon_pressed():
	for u in units:
		if not is_instance_valid(u):
			continue
		var ecm = u.find_child("ExternalCrewManager")
		if ecm != null:
			ecm.abandon()


func _on_pack_state_pressed():
	for u in units:
		if not is_instance_valid(u):
			continue
		u.set_pack_target(1.0 - u.get_pack_target())


func _on_attack_ground_pressed():
	MatchSignals.combat_command_requested.emit("attack_ground")
