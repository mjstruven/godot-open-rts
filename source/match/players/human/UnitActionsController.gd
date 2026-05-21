extends Node

const Structure = preload("res://source/match/units/Structure.gd")
const ResourceUnit = preload("res://source/match/units/non-player/ResourceUnit.gd")


class Actions:
	const Moving = preload("res://source/match/units/actions/Moving.gd")
	const MovingToUnit = preload("res://source/match/units/actions/MovingToUnit.gd")
	const Following = preload("res://source/match/units/actions/Following.gd")
	const CollectingResourcesSequentially = preload(
		"res://source/match/units/actions/CollectingResourcesSequentially.gd"
	)
	const AutoAttacking = preload("res://source/match/units/actions/AutoAttacking.gd")
	const ArcherAutoAttacking = preload("res://source/match/units/actions/ArcherAutoAttacking.gd")
	const Constructing = preload("res://source/match/units/actions/Constructing.gd")
	const AttackMoving = preload("res://source/match/units/actions/AttackMoving.gd")
	const StandingGround = preload("res://source/match/units/actions/StandingGround.gd")
	const Patrolling = preload("res://source/match/units/actions/Patrolling.gd")


var _pending_command: String = ""


func _input(event):
	if _pending_command.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_exit_targeting_mode()
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		var camera = get_viewport().get_camera_3d()
		var pos = camera.get_ray_intersection(event.position) if camera else null
		if pos != null:
			var cmd = _pending_command
			_exit_targeting_mode()
			match cmd:
				"attack_move":
					_apply_attack_move(pos)
				"patrol":
					_apply_patrol(pos)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_exit_targeting_mode()
		get_viewport().set_input_as_handled()


func _enter_targeting_mode(command: String):
	_pending_command = command
	MatchSignals.targeting_mode_changed.emit(command)
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_CROSS)


func _exit_targeting_mode():
	_pending_command = ""
	MatchSignals.targeting_mode_changed.emit("")
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)


func _set_or_queue_action(unit, creator: Callable, waypoint: Variant):
	if Input.is_key_pressed(KEY_SHIFT):
		unit.queue_action({"create": creator, "waypoint": waypoint})
	else:
		unit.action_queue.clear()
		creator.call()


func _is_constructing(unit) -> bool:
	return unit.action != null and unit.action is Actions.Constructing


func _ready():
	MatchSignals.terrain_targeted.connect(_on_terrain_targeted)
	MatchSignals.unit_targeted.connect(_on_unit_targeted)
	MatchSignals.unit_spawned.connect(_on_unit_spawned)
	MatchSignals.navigate_unit_to_rally_point.connect(_on_navigate_unit_to_rally_point)
	MatchSignals.combat_command_requested.connect(_on_combat_command_requested)


func _try_navigating_selected_units_towards_position(target_point):
	var terrain_units_to_move = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return (
				unit.is_in_group("controlled_units")
				and unit.movement_domain == Constants.Match.Navigation.Domain.TERRAIN
				and Actions.Moving.is_applicable(unit)
				and not _is_constructing(unit)
			)
	)
	var air_units_to_move = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return (
				unit.is_in_group("controlled_units")
				and unit.movement_domain == Constants.Match.Navigation.Domain.AIR
				and Actions.Moving.is_applicable(unit)
				and not _is_constructing(unit)
			)
	)
	var new_unit_targets = Utils.Match.Unit.Movement.crowd_moved_to_new_pivot(
		terrain_units_to_move, target_point
	)
	new_unit_targets += Utils.Match.Unit.Movement.crowd_moved_to_new_pivot(
		air_units_to_move, target_point
	)
	for tuple in new_unit_targets:
		var unit = tuple[0]
		var new_target = tuple[1]
		_set_or_queue_action(unit, func(): unit.action = Actions.Moving.new(new_target), new_target)


func _try_setting_rally_points(target_point: Vector3):
	var controlled_structures = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return unit.is_in_group("controlled_units") and unit.find_child("RallyPoint") != null
	)
	for structure in controlled_structures:
		var rally_point = structure.find_child("RallyPoint")
		if rally_point != null:
			rally_point.target_unit = null
			rally_point.global_position = target_point


func _try_ordering_selected_workers_to_construct_structure(potential_structure):
	if not potential_structure is Structure or potential_structure.is_constructed():
		return
	var structure = potential_structure
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if unit.is_in_group("controlled_units") and Actions.Constructing.is_applicable(unit, structure):
			unit.action = Actions.Constructing.new(structure)


func _try_queuing_selected_workers_to_construct_structure(potential_structure):
	if not potential_structure is Structure or potential_structure.is_constructed():
		return
	var structure = potential_structure
	var any_queued = false
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if not unit.is_in_group("controlled_units"):
			continue
		if unit.action is Actions.Constructing:
			unit.action.enqueue(structure)
			any_queued = true
		elif Actions.Constructing.is_applicable(unit, structure):
			unit.action = Actions.Constructing.new(structure)
			any_queued = true
	if not any_queued:
		_try_ordering_selected_workers_to_construct_structure(structure)


func _navigate_selected_units_towards_unit(target_unit):
	var at_least_one_unit_navigated = false
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if not unit.is_in_group("controlled_units"):
			continue
		if _is_constructing(unit) and not Actions.Constructing.is_applicable(unit, target_unit):
			continue
		if _navigate_unit_towards_unit(unit, target_unit):
			at_least_one_unit_navigated = true
	return at_least_one_unit_navigated


func _navigate_unit_towards_unit(unit, target_unit):
	if Actions.CollectingResourcesSequentially.is_applicable(unit, target_unit):
		unit.action_queue.clear()
		unit.action = Actions.CollectingResourcesSequentially.new(target_unit)
		return true
	if Actions.AutoAttacking.is_applicable(unit, target_unit):
		var tgt = target_unit
		var is_archer = unit.get_script() and unit.get_script().resource_path.get_file() == "archer.gd"
		var action_class = Actions.ArcherAutoAttacking if is_archer else Actions.AutoAttacking
		_set_or_queue_action(unit, func(): unit.action = action_class.new(tgt), tgt.global_position)
		return true
	if Actions.Constructing.is_applicable(unit, target_unit):
		var tgt = target_unit
		_set_or_queue_action(unit, func(): unit.action = Actions.Constructing.new(tgt), tgt.global_position)
		return true
	if (
		(target_unit.is_in_group("adversary_units") or target_unit.is_in_group("controlled_units"))
		and Actions.Following.is_applicable(unit)
	):
		var tgt = target_unit
		_set_or_queue_action(unit, func(): unit.action = Actions.Following.new(tgt), tgt.global_position)
		return true
	if Actions.MovingToUnit.is_applicable(unit):
		var tgt = target_unit
		_set_or_queue_action(unit, func(): unit.action = Actions.MovingToUnit.new(tgt), tgt.global_position)
		return true
	if _try_setting_rally_point_to_unit(unit, target_unit):
		return true
	return false  # gdlint: ignore = max-returns


func _try_setting_rally_point_to_unit(unit, target_unit):
	if not unit is Structure:
		return false
	if not target_unit is ResourceUnit and unit.player != target_unit.player:
		# it's not allowed to set rally point to enemy at the moment as with current implementation
		# the position of enemy unit hidden in the fog of war could be hinted
		return false
	var rally_point = unit.find_child("RallyPoint")
	if rally_point == null:
		return false
	rally_point.target_unit = target_unit
	return true


func _on_combat_command_requested(command: String):
	match command:
		"stand_ground":
			_apply_stand_ground()
		"attack_move", "patrol":
			_enter_targeting_mode(command)


func _apply_stand_ground():
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if (
			unit.is_in_group("controlled_units")
			and Actions.StandingGround.is_applicable(unit)
			and not _is_constructing(unit)
		):
			unit.action_queue.clear()
			unit.action = Actions.StandingGround.new()


func _on_terrain_targeted(position):
	if _pending_command == "attack_move":
		_exit_targeting_mode()
		_apply_attack_move(position)
		return
	if _pending_command == "patrol":
		_exit_targeting_mode()
		_apply_patrol(position)
		return
	_try_navigating_selected_units_towards_position(position)
	_try_setting_rally_points(position)


func _apply_attack_move(position: Vector3):
	var terrain_units = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return (
				unit.is_in_group("controlled_units")
				and unit.movement_domain == Constants.Match.Navigation.Domain.TERRAIN
				and Actions.AttackMoving.is_applicable(unit)
				and not _is_constructing(unit)
			)
	)
	var targets = Utils.Match.Unit.Movement.crowd_moved_to_new_pivot(terrain_units, position)
	for tuple in targets:
		var unit = tuple[0]
		var dest = tuple[1]
		_set_or_queue_action(unit, func(): unit.action = Actions.AttackMoving.new(dest), dest)


func _apply_patrol(position: Vector3):
	var terrain_units = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return (
				unit.is_in_group("controlled_units")
				and unit.movement_domain == Constants.Match.Navigation.Domain.TERRAIN
				and Actions.AttackMoving.is_applicable(unit)
				and not _is_constructing(unit)
			)
	)
	var targets = Utils.Match.Unit.Movement.crowd_moved_to_new_pivot(terrain_units, position)
	for tuple in targets:
		var unit = tuple[0]
		var dest = tuple[1]
		_set_or_queue_action(unit, func(): unit.action = Actions.Patrolling.new(unit.global_position, dest), dest)


func _on_unit_targeted(unit):
	if _navigate_selected_units_towards_unit(unit):
		var targetability = unit.find_child("Targetability")
		if targetability != null:
			targetability.animate()


func _on_unit_spawned(unit):
	if Input.is_key_pressed(KEY_SHIFT):
		_try_queuing_selected_workers_to_construct_structure(unit)
	else:
		_try_ordering_selected_workers_to_construct_structure(unit)


func _on_navigate_unit_to_rally_point(unit, rally_point):
	if rally_point.target_unit != null:
		_navigate_unit_towards_unit(unit, rally_point.target_unit)
	elif rally_point.global_position != rally_point.get_parent().global_position:
		unit.action = Actions.Moving.new(rally_point.global_position)
