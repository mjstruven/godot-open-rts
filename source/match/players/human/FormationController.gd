extends Node

const Moving = preload("res://source/match/units/actions/Moving.gd")
const Constructing = preload("res://source/match/units/actions/Constructing.gd")
const FormationGroup = preload("res://source/match/units/formations/FormationGroup.gd")

const FORMATION_CORE_TYPES = ["cavalry", "flag_commander", "infantry", "archer", "siege", "supply_train"]
const FORMATION_ELIGIBLE_TYPES = ["cavalry", "flag_commander", "infantry", "archer", "siege", "supply_train", "engineer"]

var _group: Node = null
var _pending_command: String = ""
var _formation_type: int = FormationGroup.Type.COLUMN
var _scattered: bool = false


func _ready():
	add_to_group("formation_controller")
	MatchSignals.terrain_targeted.connect(_on_terrain_targeted)
	MatchSignals.unit_died.connect(_on_unit_died)
	MatchSignals.combat_command_requested.connect(_on_combat_command_requested)


func _on_combat_command_requested(command: String):
	if command in ["attack_move", "patrol", "stand_ground"]:
		_pending_command = command
		_disband()


func has_active_formation() -> bool:
	return _group != null and not _group.members.is_empty()


func can_form() -> bool:
	var eligible = _get_eligible_selected_units()
	var core = eligible.filter(func(u): return u.type in FORMATION_CORE_TYPES)
	return core.size() >= 2


func selection_formation_state() -> Dictionary:
	var eligible = _get_eligible_selected_units()
	var core = eligible.filter(func(u): return u.type in FORMATION_CORE_TYPES)
	if core.size() < 2:
		return {"can_form": false}
	if _group != null:
		var current = _group.members.filter(func(u): return is_instance_valid(u))
		if _same_members(current, eligible):
			return {"can_form": true, "type": _group.formation_type, "scattered": _group.scattered}
	return {"can_form": true, "type": FormationGroup.Type.COLUMN, "scattered": false}


func get_formation_type() -> int:
	return _group.formation_type if _group != null else _formation_type


func get_scattered() -> bool:
	return _group.scattered if _group != null else _scattered


func set_formation_type(t: int):
	_formation_type = t
	var _in_form = get_tree().get_nodes_in_group("in_formation")
	print("[FormBtn] set_formation_type type=%d group_id=%s" % [t, str(_group.get_instance_id()) if _group != null else "null"])
	print("[FormInGroup] count=%d units=%s" % [_in_form.size(), _in_form.map(func(u): return u.name)])
	if not _sync_group_to_selection():
		return
	_group.set_formation_type(t)
	MatchSignals.formation_changed.emit()


func set_scattered(v: bool):
	_scattered = v
	var _in_form = get_tree().get_nodes_in_group("in_formation")
	print("[FormBtn] set_scattered scattered=%s group_id=%s" % [v, str(_group.get_instance_id()) if _group != null else "null"])
	print("[FormInGroup] count=%d units=%s" % [_in_form.size(), _in_form.map(func(u): return u.name)])
	if not _sync_group_to_selection():
		return
	_group.set_scattered(v)
	MatchSignals.formation_changed.emit()


func disband_formation():
	_disband()


func _on_terrain_targeted(position: Vector3):
	if _pending_command != "":
		_pending_command = ""
		return

	var eligible = _get_eligible_selected_units()
	var core = eligible.filter(func(u): return u.type in FORMATION_CORE_TYPES)

	if core.size() < 2:
		_disband()
		return

	if _group != null:
		var current = _group.members.filter(func(u): return is_instance_valid(u))
		if _same_members(current, eligible):
			_group.issue_move(position)
			return
		_disband()

	_group = FormationGroup.new()
	add_child(_group)
	_group.formation_type = _formation_type
	_group.scattered = _scattered
	_group.setup(eligible)
	_group.issue_move(position)
	MatchSignals.formation_changed.emit()


func _on_unit_died(unit):
	if _group == null or unit not in _group.members:
		return
	_group.on_member_died(unit)
	var remaining_core = _group.members.filter(
		func(u): return is_instance_valid(u) and u.type in FORMATION_CORE_TYPES
	)
	if remaining_core.size() < 2:
		_disband()
	else:
		MatchSignals.formation_changed.emit()


func _sync_group_to_selection() -> bool:
	var eligible = _get_eligible_selected_units()
	var core = eligible.filter(func(u): return u.type in FORMATION_CORE_TYPES)
	if core.size() < 2:
		return false
	if _group != null:
		var current = _group.members.filter(func(u): return is_instance_valid(u))
		if _same_members(current, eligible):
			return true
		_disband()
	_group = FormationGroup.new()
	add_child(_group)
	_group.formation_type = _formation_type
	_group.scattered = _scattered
	_group.setup(eligible)
	return true


func _disband():
	if _group == null:
		return
	_group.disband()
	_group.queue_free()
	_group = null
	MatchSignals.formation_changed.emit()


func _get_eligible_selected_units() -> Array:
	return get_tree().get_nodes_in_group("selected_units").filter(
		func(unit):
			return (
				unit.is_in_group("controlled_units")
				and unit.movement_domain == Constants.Match.Navigation.Domain.TERRAIN
				and Moving.is_applicable(unit)
				and not _is_constructing(unit)
				and unit.type in FORMATION_ELIGIBLE_TYPES
			)
	)


func _is_constructing(unit) -> bool:
	return unit.action != null and unit.action is Constructing


func _same_members(current: Array, new_units: Array) -> bool:
	if current.size() != new_units.size():
		return false
	for u in new_units:
		if u not in current:
			return false
	return true
