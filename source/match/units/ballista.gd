extends "res://source/match/units/Unit.gd"

const ATTACK_MIN_RANGE: float = 3.0
const ATTACK_AOE_DAMAGE: int = 25
const MIN_CREW_TO_FUNCTION: int = 2

const BallistaWaitingForTargets = preload(
	"res://source/match/units/actions/BallistaWaitingForTargets.gd"
)
const BallistaAutoAttacking = preload(
	"res://source/match/units/actions/BallistaAutoAttacking.gd"
)
const BallistaAttackGround = preload(
	"res://source/match/units/actions/BallistaAttackGround.gd"
)
const Circle3D = preload("res://source/generic-scenes-and-nodes/3d/Circle3D.gd")

var _range_circles: Array = []


func _ready():
	await super()
	add_to_group("siege_units")
	add_to_group("neutral_siege")
	var mv = find_child("Movement")
	if mv != null:
		mv.avoidance_enabled = false
	set_meta("attack_min_range", ATTACK_MIN_RANGE)
	set_meta("attack_aoe_damage", ATTACK_AOE_DAMAGE)
	action = BallistaWaitingForTargets.new()
	var ecm = find_child("ExternalCrewManager")
	if ecm != null:
		ecm.crew_changed.connect(_on_crew_changed)
	action_changed.connect(_on_action_changed)
	selected.connect(_show_range_circles)
	deselected.connect(_hide_range_circles)


func _on_action_changed(new_action) -> void:
	if new_action != null:
		return
	if not is_inside_tree():
		return
	var ecm = find_child("ExternalCrewManager")
	if ecm != null and ecm.crew_count() >= MIN_CREW_TO_FUNCTION:
		action = BallistaWaitingForTargets.new()


func _on_crew_changed(new_count: int) -> void:
	if new_count < MIN_CREW_TO_FUNCTION:
		action_queue.clear()
		action = BallistaWaitingForTargets.new()


func _show_range_circles():
	if _range_circles.is_empty():
		_range_circles.append(_make_siege_range_circle(ATTACK_MIN_RANGE))
		_range_circles.append(_make_siege_range_circle(attack_range if attack_range != null else 15.0))
	for c in _range_circles:
		if is_instance_valid(c):
			c.show()


func _hide_range_circles():
	for c in _range_circles:
		if is_instance_valid(c):
			c.hide()


func _make_siege_range_circle(r: float) -> Node3D:
	var circle = Circle3D.new()
	circle.radius = r
	circle.width = 3.0
	circle.color = Color.RED
	circle.render_priority = 1
	add_child(circle)
	circle.hide()
	return circle


func _set_action(action_node):
	if action_node != null and not (action_node is BallistaWaitingForTargets):
		var ecm = find_child("ExternalCrewManager")
		if ecm != null and ecm.crew_count() < MIN_CREW_TO_FUNCTION:
			action_node.queue_free()
			return
	if action_node is BallistaAutoAttacking:
		var target = action_node._target_unit
		if is_instance_valid(target):
			var dist = global_position_yless.distance_to(target.global_position_yless)
			if dist < ATTACK_MIN_RANGE:
				action_node.queue_free()
				if is_instance_valid(player):
					MatchSignals.alert_message.emit(player, "The target is too close")
				return
	elif action_node is BallistaAttackGround:
		var tp = action_node._target_pos
		var dist = global_position_yless.distance_to(Vector3(tp.x, 0.0, tp.z))
		if dist < ATTACK_MIN_RANGE:
			action_node.queue_free()
			if is_instance_valid(player):
				MatchSignals.alert_message.emit(player, "The target is too close")
			return
	super(action_node)


func _handle_unit_death():
	var ecm = find_child("ExternalCrewManager")
	if ecm != null:
		for eng in ecm.get_all_engineers():
			if is_instance_valid(eng):
				eng.hp = 0
	super()


func refresh_player_color():
	var geo = find_child("Geometry")
	if geo == null:
		return
	var mat = player.get_color_material() if is_instance_valid(player) else null
	for child in geo.find_children("*", "MeshInstance3D", true, false):
		child.material_override = mat


func reset_player_color():
	var geo = find_child("Geometry")
	if geo == null:
		return
	for child in geo.find_children("*", "MeshInstance3D", true, false):
		child.material_override = null
