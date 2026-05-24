extends GridContainer

const RALLY_TOOLTIP = (
	"Rally [F]\n"
	+ "Boost nearby allied units: +20% speed, +20% attack rate.\n"
	+ "Radius: 8 tiles. Duration: 15s. Cooldown: 45s."
)

var units: Array = []:
	set(value):
		units = value
		if is_node_ready():
			_update_rally_button()

@onready var _rally_btn = find_child("RallyButton")

var _poll_timer: Timer = null


func _ready():
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.5
	_poll_timer.timeout.connect(_update_rally_button)
	add_child(_poll_timer)
	_poll_timer.start()
	_update_rally_button()


func _unhandled_input(event):
	if not is_visible_in_tree():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_F:
		_handle_rally_click()
		get_viewport().set_input_as_handled()


func _get_flag_commanders() -> Array:
	return units.filter(func(u): return is_instance_valid(u) and u.type == "flag_commander")


func _handle_rally_click():
	var fcs = _get_flag_commanders()
	if fcs.is_empty():
		return
	for fc in fcs:
		var ability = fc.find_child("RallyAbility")
		if ability != null and ability.is_ready():
			ability.activate()
			break
	_update_rally_button()


func _update_rally_button():
	if not is_instance_valid(_rally_btn):
		return
	var fcs = _get_flag_commanders()
	if fcs.is_empty():
		_rally_btn.disabled = true
		_rally_btn.modulate = Color(0.5, 0.5, 0.5)
		_rally_btn.tooltip_text = "Rally (no Flag Commander selected)"
		return
	_rally_btn.disabled = false
	var fc = fcs[0]
	var ability = fc.find_child("RallyAbility")
	if ability == null or ability.is_ready():
		_rally_btn.modulate = Color.WHITE
		_rally_btn.tooltip_text = RALLY_TOOLTIP
	else:
		var remaining = int(ceil(ability.get_cooldown_remaining()))
		_rally_btn.modulate = Color(0.5, 0.5, 0.5)
		_rally_btn.tooltip_text = "Rally on cooldown (%ds)" % remaining
