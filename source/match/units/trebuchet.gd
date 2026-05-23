extends "res://source/match/units/Unit.gd"

const PACK_RATE: float = 1.0 / 15.0
const MIN_CREW_TO_FUNCTION: int = 2

const MovingAction = preload("res://source/match/units/actions/Moving.gd")
const AttackMovingAction = preload("res://source/match/units/actions/AttackMoving.gd")
const FollowingAction = preload("res://source/match/units/actions/Following.gd")

# 0.0 = fully packed, 1.0 = fully unpacked
var _pack_progress: float = 0.0
var _pack_target: float = 0.0

@onready var _charge_bar_sprite = find_child("ChargeBarSprite")


func _ready():
	await super()
	add_to_group("siege_units")
	add_to_group("neutral_siege")
	var mv = find_child("Movement")
	if mv != null:
		mv.avoidance_enabled = false
	var ecm = find_child("ExternalCrewManager")
	if ecm != null:
		ecm.crew_changed.connect(_on_crew_changed)
	_update_charge_bar()


func _process(delta: float) -> void:
	super(delta)
	if _pack_progress == _pack_target:
		return
	if _pack_target > _pack_progress:
		_pack_progress = minf(_pack_progress + PACK_RATE * delta, _pack_target)
	else:
		_pack_progress = maxf(_pack_progress - PACK_RATE * delta, _pack_target)
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
	# When starting to unpack from fully packed, stop any current movement action.
	if _pack_target > 0.0 and _pack_progress == 0.0:
		action_queue.clear()
		action = null


func _set_action(action_node):
	if action_node != null:
		var ecm = find_child("ExternalCrewManager")
		if ecm != null and ecm.crew_count() < MIN_CREW_TO_FUNCTION:
			action_node.queue_free()
			if is_instance_valid(player):
				MatchSignals.alert_message.emit(player, "Needs at least 2 engineers to operate")
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
			if is_instance_valid(player):
				MatchSignals.alert_message.emit(player, "Pack the trebuchet before moving")
			return
	super(action_node)


func _on_crew_changed(_new_count: int) -> void:
	pass


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


func _update_charge_bar() -> void:
	if _charge_bar_sprite == null:
		return
	var offset = 1.1 if _pack_progress >= 1.0 else _pack_progress
	_charge_bar_sprite.texture.gradient.set_offset(1, offset)
