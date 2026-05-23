extends "res://source/match/units/Unit.gd"

const PACK_RATE: float = 1.0 / 15.0
const MIN_CREW_TO_FUNCTION: int = 2
const ATTACK_MIN_RANGE: float = 7.0

const MovingAction = preload("res://source/match/units/actions/Moving.gd")
const AttackMovingAction = preload("res://source/match/units/actions/AttackMoving.gd")
const FollowingAction = preload("res://source/match/units/actions/Following.gd")
const TrebuchetWaitingForTargets = preload(
	"res://source/match/units/actions/TrebuchetWaitingForTargets.gd"
)
const TrebuchetAutoAttacking = preload(
	"res://source/match/units/actions/TrebuchetAutoAttacking.gd"
)
const TrebuchetAttackGround = preload(
	"res://source/match/units/actions/TrebuchetAttackGround.gd"
)
const Circle3D = preload("res://source/generic-scenes-and-nodes/3d/Circle3D.gd")

# 0.0 = fully packed, 1.0 = fully unpacked
var _pack_progress: float = 0.0
var _pack_target: float = 0.0
var _range_circles: Array = []

@onready var _charge_bar_sprite = find_child("ChargeBarSprite")
@onready var _mast_mesh = find_child("Mast")
@onready var _arm_mesh = find_child("Arm")
@onready var _counterweight_mesh = find_child("Counterweight")


func _ready():
	await super()
	add_to_group("siege_units")
	add_to_group("neutral_siege")
	var mv = find_child("Movement")
	if mv != null:
		mv.avoidance_enabled = false
	set_meta("attack_min_range", ATTACK_MIN_RANGE)
	action = TrebuchetWaitingForTargets.new()
	var ecm = find_child("ExternalCrewManager")
	if ecm != null:
		ecm.crew_changed.connect(_on_crew_changed)
	action_changed.connect(_on_action_changed)
	selected.connect(_show_range_circles)
	deselected.connect(_hide_range_circles)
	_update_charge_bar()


func _process(delta: float) -> void:
	super(delta)
	if _pack_progress == _pack_target:
		return
	var prev := _pack_progress
	if _pack_target > _pack_progress:
		_pack_progress = minf(_pack_progress + PACK_RATE * delta, _pack_target)
	else:
		_pack_progress = maxf(_pack_progress - PACK_RATE * delta, _pack_target)
	if prev < 1.0 and _pack_progress >= 1.0:
		set_meta("treb_first_shot", true)
	_update_charge_bar()


func get_pack_state() -> String:
	if _pack_progress == 0.0 and _pack_target == 0.0:
		return "PACKED"
	if _pack_progress == 1.0 and _pack_target == 1.0:
		return "UNPACKED"
	return "TRANSITIONING"


func get_pack_target() -> float:
	return _pack_target


func set_pack_target(t: float) -> void:
	_pack_target = clampf(t, 0.0, 1.0)
	# When starting to unpack from fully packed, stop any current action —
	# but not attack actions that manage their own pack state.
	if _pack_target > 0.0 and _pack_progress == 0.0:
		if action is TrebuchetAutoAttacking or action is TrebuchetAttackGround:
			return
		action_queue.clear()
		action = null


func _set_action(action_node):
	if action_node != null and not (action_node is TrebuchetWaitingForTargets):
		var ecm = find_child("ExternalCrewManager")
		if ecm != null and ecm.crew_count() < MIN_CREW_TO_FUNCTION:
			action_node.queue_free()
			return
	if (
		action_node != null
		and (
			action_node is MovingAction
			or action_node is AttackMovingAction
			or action_node is FollowingAction
		)
	):
		if not (_pack_progress == 0.0 and _pack_target == 0.0):
			action_node.queue_free()
			if is_in_group("controlled_units"):
				MatchSignals.alert_message.emit(player, "Pack the trebuchet before moving")
			return
	super(action_node)


func _on_action_changed(new_action) -> void:
	if new_action != null:
		return
	if not is_inside_tree():
		return
	var ecm = find_child("ExternalCrewManager")
	if ecm != null and ecm.crew_count() >= MIN_CREW_TO_FUNCTION:
		action = TrebuchetWaitingForTargets.new()


func _on_crew_changed(new_count: int) -> void:
	if new_count < MIN_CREW_TO_FUNCTION:
		action_queue.clear()
		action = TrebuchetWaitingForTargets.new()


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


func _show_range_circles():
	if _range_circles.is_empty():
		_range_circles.append(_make_siege_range_circle(7.0))
		_range_circles.append(_make_siege_range_circle(13.0))
		_range_circles.append(_make_siege_range_circle(19.0))
		_range_circles.append(_make_siege_range_circle(25.0))
		_range_circles.append(_make_siege_range_circle(attack_range if attack_range != null else 30.0))
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


func _update_charge_bar() -> void:
	if _charge_bar_sprite == null:
		return
	var offset = 1.1 if _pack_progress >= 1.0 else _pack_progress
	_charge_bar_sprite.texture.gradient.set_offset(1, offset)
	var extended = _pack_progress > 0.0
	if _mast_mesh != null:
		_mast_mesh.visible = extended
	if _arm_mesh != null:
		_arm_mesh.visible = extended
	if _counterweight_mesh != null:
		_counterweight_mesh.visible = extended
