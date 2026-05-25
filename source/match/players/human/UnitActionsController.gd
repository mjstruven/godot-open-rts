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
	const RamAutoAttacking = preload("res://source/match/units/actions/RamAutoAttacking.gd")
	const LoadingIntoCrew = preload("res://source/match/units/actions/LoadingIntoCrew.gd")
	const ApproachingExternalCrew = preload(
		"res://source/match/units/actions/ApproachingExternalCrew.gd"
	)
	const BallistaAutoAttacking = preload(
		"res://source/match/units/actions/BallistaAutoAttacking.gd"
	)
	const BallistaAttackGround = preload(
		"res://source/match/units/actions/BallistaAttackGround.gd"
	)
	const TrebuchetAutoAttacking = preload(
		"res://source/match/units/actions/TrebuchetAutoAttacking.gd"
	)
	const TrebuchetAttackGround = preload(
		"res://source/match/units/actions/TrebuchetAttackGround.gd"
	)
	const Constructing = preload("res://source/match/units/actions/Constructing.gd")
	const AttackMoving = preload("res://source/match/units/actions/AttackMoving.gd")
	const StandingGround = preload("res://source/match/units/actions/StandingGround.gd")
	const Patrolling = preload("res://source/match/units/actions/Patrolling.gd")
	const ChargingPhaseA = preload("res://source/match/units/actions/ChargingPhaseA.gd")
	const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")


const BolsterBuff = preload("res://source/match/units/traits/BolsterBuff.gd")

var _pending_command: String = ""
var _crosshair_image: Image = null


func _input(event):
	if (
		_pending_command.is_empty()
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.ctrl_pressed
	):
		match event.keycode:
			KEY_Q:
				_try_subselect_infantry(false)
				get_viewport().set_input_as_handled()
				return
			KEY_W:
				_try_subselect_infantry(true)
				get_viewport().set_input_as_handled()
				return
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
				"attack_ground":
					var space_state = get_viewport().get_world_3d().direct_space_state
					var ray_from = camera.project_ray_origin(event.position)
					var ray_query = PhysicsRayQueryParameters3D.create(
						ray_from, ray_from + camera.project_ray_normal(event.position) * 1000.0, 2
					)
					ray_query.collide_with_areas = true
					ray_query.collide_with_bodies = false
					var ray_result = space_state.intersect_ray(ray_query)
					var hit_unit = ray_result.get("collider") if not ray_result.is_empty() else null
					if hit_unit != null and hit_unit.is_in_group("units"):
						if _navigate_selected_units_towards_unit(hit_unit):
							var targetability = hit_unit.find_child("Targetability")
							if targetability != null:
								targetability.animate()
					else:
						_apply_attack_ground(pos)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_exit_targeting_mode()
		get_viewport().set_input_as_handled()


func _build_crosshair_image() -> Image:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var white = Color(1, 1, 1, 1)
	var outline = Color(0, 0, 0, 0.7)
	for x in range(32):
		for y in range(32):
			var arm_v = (x == 15 or x == 16) and not (y >= 13 and y <= 18)
			var arm_h = (y == 15 or y == 16) and not (x >= 13 and x <= 18)
			var near_v = (x == 14 or x == 17) and not (y >= 12 and y <= 19)
			var near_h = (y == 14 or y == 17) and not (x >= 12 and x <= 19)
			if arm_v or arm_h:
				img.set_pixel(x, y, white)
			elif near_v or near_h:
				img.set_pixel(x, y, outline)
	return img


func _enter_targeting_mode(command: String):
	if get_tree().get_nodes_in_group("placement_active").size() > 0:
		return
	_pending_command = command
	MatchSignals.targeting_mode_changed.emit(command)
	add_to_group("targeting_mode_active")
	DisplayServer.cursor_set_custom_image(_crosshair_image, DisplayServer.CURSOR_ARROW, Vector2(15, 15))


func _exit_targeting_mode():
	_pending_command = ""
	MatchSignals.targeting_mode_changed.emit("")
	remove_from_group("targeting_mode_active")
	DisplayServer.cursor_set_custom_image(null, DisplayServer.CURSOR_ARROW)


func _set_or_queue_action(unit, creator: Callable, waypoint: Variant):
	if Input.is_key_pressed(KEY_SHIFT):
		unit.queue_action({"create": creator, "waypoint": waypoint})
	else:
		unit.action_queue.clear()
		creator.call()


func _is_constructing(unit) -> bool:
	return unit.action != null and unit.action is Actions.Constructing


func _emit_needs_crew_if_uncrewed_siege_selected() -> void:
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if unit.is_in_group("neutral_siege") and unit.is_in_group("siege_units"):
			MatchSignals.alert_message.emit(get_parent(), "Needs a crew to operate")
			return


func _ready():
	_crosshair_image = _build_crosshair_image()
	MatchSignals.terrain_targeted.connect(_on_terrain_targeted)
	MatchSignals.unit_targeted.connect(_on_unit_targeted)
	MatchSignals.unit_spawned.connect(_on_unit_spawned)
	MatchSignals.navigate_unit_to_rally_point.connect(_on_navigate_unit_to_rally_point)
	MatchSignals.combat_command_requested.connect(_on_combat_command_requested)
	var ctm = get_parent().find_child("ChargeTargetingMode")
	if ctm != null:
		ctm.charge_area_confirmed.connect(_on_charge_area_confirmed)


func _try_navigating_selected_units_towards_position(target_point):
	var terrain_units_to_move = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return (
				unit.is_in_group("controlled_units")
				and unit.movement_domain == Constants.Match.Navigation.Domain.TERRAIN
				and Actions.Moving.is_applicable(unit)
				and not _is_constructing(unit)
				and not unit.is_in_group("suppressing")
			)
	)
	var air_units_to_move = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return (
				unit.is_in_group("controlled_units")
				and unit.movement_domain == Constants.Match.Navigation.Domain.AIR
				and Actions.Moving.is_applicable(unit)
				and not _is_constructing(unit)
				and not unit.is_in_group("suppressing")
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
	_emit_needs_crew_if_uncrewed_siege_selected()


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
	var emitted_needs_crew := false
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if not unit.is_in_group("controlled_units"):
			if not emitted_needs_crew and unit.is_in_group("neutral_siege"):
				MatchSignals.alert_message.emit(get_parent(), "Needs a crew to operate")
				emitted_needs_crew = true
			continue
		if _is_constructing(unit) and not Actions.Constructing.is_applicable(unit, target_unit):
			continue
		if _navigate_unit_towards_unit(unit, target_unit):
			at_least_one_unit_navigated = true
	return at_least_one_unit_navigated


func _navigate_unit_towards_unit(unit, target_unit):
	if unit.is_in_group("in_crew"):
		return false
	if unit.is_in_group("suppressing"):
		var dist = unit.global_position_yless.distance_to(target_unit.global_position_yless)
		if dist <= unit.attack_range and Actions.AutoAttacking.is_applicable(unit, target_unit):
			var suppress_action = unit.get_meta("suppress_action", null)
			if is_instance_valid(suppress_action):
				suppress_action.retarget(target_unit)
				return true
		return false
	if unit.is_in_group("suppress_armed"):
		var dist = unit.global_position_yless.distance_to(target_unit.global_position_yless)
		if dist > unit.attack_range or not Actions.AutoAttacking.is_applicable(unit, target_unit):
			return false
		# In range: fall through — ArcherAutoAttacking will activate SuppressedAttacking
	# External crew loading (Ballista, Trebuchet, etc.)
	var external_crew_mgr = target_unit.find_child("ExternalCrewManager")
	if external_crew_mgr != null:
		var can_crew = (
			target_unit.is_in_group("neutral_siege") or target_unit.player == unit.player
		)
		if can_crew and external_crew_mgr.can_accept_unit(unit):
			var tgt = target_unit
			_set_or_queue_action(
				unit,
				func(): unit.action = Actions.ApproachingExternalCrew.new(tgt),
				tgt.global_position
			)
			return true
	# Crew loading: infantry/archer right-clicking a neutral or same-player siege unit
	var crew_manager = target_unit.find_child("CrewManager")
	if crew_manager != null:
		var can_crew = (
			target_unit.is_in_group("neutral_siege") or target_unit.player == unit.player
		)
		if can_crew and crew_manager.can_accept_unit(unit):
			var tgt = target_unit
			_set_or_queue_action(
				unit, func(): unit.action = Actions.LoadingIntoCrew.new(tgt), tgt.global_position
			)
			return true
	if Actions.CollectingResourcesSequentially.is_applicable(unit, target_unit):
		unit.action_queue.clear()
		unit.action = Actions.CollectingResourcesSequentially.new(target_unit)
		return true
	if Actions.AutoAttacking.is_applicable(unit, target_unit):
		var tgt = target_unit
		var unit_script_file = (
			unit.get_script().resource_path.get_file() if unit.get_script() else ""
		)
		var is_archer = unit_script_file == "archer.gd"
		var is_ram = unit_script_file == "battering_ram.gd"
		var is_trebuchet = unit_script_file == "trebuchet.gd"
		var is_ballista = unit.find_child("ExternalCrewManager") != null and not is_trebuchet
		if is_ram:
			if Actions.RamAutoAttacking.is_applicable(unit, tgt):
				_set_or_queue_action(
					unit,
					func(): unit.action = Actions.RamAutoAttacking.new(tgt),
					tgt.global_position
				)
				return true
			# Ram cannot attack this target type — fall through to follow/move
		elif is_trebuchet:
			if Actions.TrebuchetAutoAttacking.is_applicable(unit, tgt):
				_set_or_queue_action(
					unit,
					func(): unit.action = Actions.TrebuchetAutoAttacking.new(tgt),
					tgt.global_position
				)
				return true
			# Trebuchet undercrewed — fall through to follow/move
		elif is_ballista:
			if Actions.BallistaAutoAttacking.is_applicable(unit, tgt):
				_set_or_queue_action(
					unit,
					func(): unit.action = Actions.BallistaAutoAttacking.new(tgt),
					tgt.global_position
				)
				return true
		else:
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
	if target_unit.is_in_group("siege_units"):
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
		"attack_ground":
			_enter_targeting_mode(command)
		"charge":
			var ctm = get_parent().find_child("ChargeTargetingMode")
			if ctm != null:
				ctm.enter()
		"bolster":
			for unit in get_tree().get_nodes_in_group("selected_units"):
				if (
					unit.is_in_group("controlled_units")
					and unit.get("type") == "infantry"
					and not unit.is_in_group("bolstering")
					and _is_bolster_ready(unit)
				):
					var buff = BolsterBuff.new()
					buff.name = "BolsterBuff"
					unit.add_child(buff)
		"cancel_bolster":
			for unit in get_tree().get_nodes_in_group("selected_units"):
				if unit.is_in_group("controlled_units") and unit.is_in_group("bolstering"):
					for child in unit.get_children():
						if child is BolsterBuff:
							child.queue_free()
							break


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
	if _pending_command == "attack_ground":
		_exit_targeting_mode()
		_apply_attack_ground(position)
		return
	_try_navigating_selected_units_towards_position(position)
	_try_setting_rally_points(position)


func _retarget_suppressing_to_nearest_in_range(unit) -> void:
	var suppress_action = unit.get_meta("suppress_action", null)
	if not is_instance_valid(suppress_action):
		return
	var candidates = get_tree().get_nodes_in_group("adversary_units").filter(
		func(candidate):
			return (
				Actions.AutoAttacking.is_applicable(unit, candidate)
				and unit.global_position_yless.distance_to(candidate.global_position_yless)
					<= unit.attack_range
			)
	)
	if candidates.is_empty():
		return
	var nearest = candidates[0]
	var nearest_dist = unit.global_position_yless.distance_to(nearest.global_position_yless)
	for candidate in candidates:
		var d = unit.global_position_yless.distance_to(candidate.global_position_yless)
		if d < nearest_dist:
			nearest_dist = d
			nearest = candidate
	suppress_action.retarget(nearest)


func _apply_attack_move(position: Vector3):
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if unit.is_in_group("controlled_units") and unit.is_in_group("suppressing"):
			_retarget_suppressing_to_nearest_in_range(unit)
	var terrain_units = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			var sf = unit.get_script().resource_path.get_file() if unit.get_script() else ""
			return (
				unit.is_in_group("controlled_units")
				and unit.movement_domain == Constants.Match.Navigation.Domain.TERRAIN
				and Actions.AttackMoving.is_applicable(unit)
				and sf != "trebuchet.gd"
				and not _is_constructing(unit)
				and not unit.is_in_group("suppressing")
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
			var sf = unit.get_script().resource_path.get_file() if unit.get_script() else ""
			return (
				unit.is_in_group("controlled_units")
				and unit.movement_domain == Constants.Match.Navigation.Domain.TERRAIN
				and Actions.AttackMoving.is_applicable(unit)
				and sf != "trebuchet.gd"
				and not _is_constructing(unit)
				and not unit.is_in_group("suppressing")
			)
	)
	var targets = Utils.Match.Unit.Movement.crowd_moved_to_new_pivot(terrain_units, position)
	for tuple in targets:
		var unit = tuple[0]
		var dest = tuple[1]
		_set_or_queue_action(unit, func(): unit.action = Actions.Patrolling.new(unit.global_position, dest), dest)


func _apply_attack_ground(position: Vector3):
	for unit in get_tree().get_nodes_in_group("selected_units"):
		if not unit.is_in_group("controlled_units"):
			continue
		var ecm = unit.find_child("ExternalCrewManager")
		if ecm == null or ecm.crew_count() < 2:
			continue
		if unit.attack_range == null:
			continue
		var min_range: float = unit.get_meta("attack_min_range", 0.0)
		var dist = unit.global_position_yless.distance_to(Vector3(position.x, 0.0, position.z))
		if dist < min_range:
			if is_instance_valid(unit.player):
				MatchSignals.alert_message.emit(unit.player, "The target is too close")
			continue
		if dist > unit.attack_range:
			continue
		var tgt_pos = position
		var unit_script_file = unit.get_script().resource_path.get_file() if unit.get_script() else ""
		if unit_script_file == "trebuchet.gd":
			if unit.get_pack_state() != "UNPACKED":
				if is_instance_valid(unit.player):
					MatchSignals.alert_message.emit(unit.player, "Unpack trebuchet before firing")
				continue
			_set_or_queue_action(
				unit, func(): unit.action = Actions.TrebuchetAttackGround.new(tgt_pos), tgt_pos
			)
		else:
			_set_or_queue_action(
				unit, func(): unit.action = Actions.BallistaAttackGround.new(tgt_pos), tgt_pos
			)


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


func _is_bolster_ready(unit) -> bool:
	return (
		not unit.has_meta("bolster_cooldown_end_ms")
		or Time.get_ticks_msec() >= unit.get_meta("bolster_cooldown_end_ms")
	)


func _on_charge_area_confirmed(
	start_pos: Vector3, end_pos: Vector3, direction: Vector3, distance: float
):
	var ctm = get_parent().find_child("ChargeTargetingMode")
	var participants: Array = ctm.last_charge_participants if ctm != null else []
	if participants.is_empty():
		return
	var n = participants.size()
	var perp = direction.cross(Vector3.UP)
	for i in range(n):
		var lateral = perp * (float(i) - float(n - 1) * 0.5)
		var lane_start = start_pos + lateral
		var unit = participants[i]
		unit.action_queue.clear()
		unit.action = Actions.ChargingPhaseA.new(lane_start, direction, distance)
	var on_cooldown_cavalry = get_tree().get_nodes_in_group("selected_units").filter(
		func(u): return (
			u.is_in_group("controlled_units")
			and u.get("type") == "cavalry"
			and not participants.has(u)
		)
	)
	for unit in on_cooldown_cavalry:
		if Actions.AttackMoving.is_applicable(unit):
			unit.action_queue.clear()
			unit.action = Actions.AttackMoving.new(end_pos)
	var fc_units = get_tree().get_nodes_in_group("selected_units").filter(
		func(u): return u.is_in_group("controlled_units") and u.is_in_group("flag_commanders")
	)
	for j in range(fc_units.size()):
		var lateral = perp * (float(n + j) - float(n - 1) * 0.5)
		var lane_start = start_pos + lateral
		var fc = fc_units[j]
		fc.action_queue.clear()
		fc.action = Actions.ChargingPhaseA.new(lane_start, direction, distance)


func _on_navigate_unit_to_rally_point(unit, rally_point):
	if rally_point.target_unit != null:
		_navigate_unit_towards_unit(unit, rally_point.target_unit)
	elif rally_point.global_position != rally_point.get_parent().global_position:
		unit.action = Actions.Moving.new(rally_point.global_position)


func _try_subselect_infantry(bolstered: bool):
	var selected = get_tree().get_nodes_in_group("selected_units")
	var infantry = selected.filter(func(u): return is_instance_valid(u) and u.get("type") == "infantry")
	var bolstering = infantry.filter(func(u): return u.is_in_group("bolstering"))
	var non_bolstering = infantry.filter(func(u): return not u.is_in_group("bolstering"))
	if bolstering.is_empty() or non_bolstering.is_empty():
		return
	var targets = bolstering if bolstered else non_bolstering
	MatchSignals.deselect_all_units.emit()
	for unit in targets:
		var sel = unit.find_child("Selection")
		if sel != null:
			sel.select()
