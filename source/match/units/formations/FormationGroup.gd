extends Node

const Moving = preload("res://source/match/units/actions/Moving.gd")
const LoadingIntoGarrison = preload("res://source/match/units/actions/LoadingIntoGarrison.gd")
const LoadingIntoCrew = preload("res://source/match/units/actions/LoadingIntoCrew.gd")
const ApproachingExternalCrew = preload("res://source/match/units/actions/ApproachingExternalCrew.gd")

enum Type { COLUMN, BOX, RANKS }

const SLOT_SPACING = 1.0
const SLOT_SPACING_SCATTERED = 2.0
const SPEED_CAP_INTERVAL = 0.1
const ANCHOR_MOVE_THRESHOLD = 0.1

const _LINE_PRIORITY = {
	"cavalry": 0,
	"flag_commander": 0,
	"infantry": 1,
	"archer": 2,
	"siege": 3,
	"supply_train": 4,
	"engineer": 5,
}

var formation_type: int = Type.COLUMN
var scattered: bool = false
var members: Array = []

var _slot_positions: Dictionary = {}
var _slot_offsets: Dictionary = {}
var _last_target: Vector3 = Vector3.ZERO
var _last_facing: Vector3 = -Vector3.FORWARD
var _anchor_pos: Vector3 = Vector3.ZERO
var _anchor_speed: float = 0.0
var _speed_timer: float = 0.0


func setup(units: Array):
	members = units.duplicate()
	for unit in members:
		unit.add_to_group("in_formation")


func disband():
	for unit in members.duplicate():
		_release_unit(unit)
	members.clear()
	_slot_positions.clear()
	_slot_offsets.clear()


func issue_move(target: Vector3):
	_last_target = target
	var center = _group_center()
	var dir = target - center
	dir.y = 0.0
	if dir.length() > 0.1:
		_last_facing = dir.normalized()
	_anchor_pos = center
	_anchor_speed = _compute_anchor_speed()
	_issue_slots(_anchor_pos, _last_facing)
	# Shift anchor forward so the rearmost slot lands at the group center,
	# preventing front-rank units from stepping backward on a move order.
	var max_rear := 0.0
	for offset in _slot_offsets.values():
		max_rear = minf(max_rear, offset.dot(_last_facing))
	var shift := -max_rear  # max_rear <= 0, so shift >= 0
	_anchor_pos += _last_facing * shift
	if shift > ANCHOR_MOVE_THRESHOLD:
		_update_slot_targets()


func on_member_died(unit):
	members.erase(unit)
	_slot_positions.erase(unit)
	_slot_offsets.erase(unit)
	if unit.is_in_group("in_formation"):
		unit.remove_from_group("in_formation")
	if members.is_empty():
		disband()


func set_formation_type(t: int):
	formation_type = t
	var anchor = _anchor_pos if _anchor_pos != Vector3.ZERO else _group_center()
	_issue_slots(anchor, _last_facing)


func set_scattered(v: bool):
	scattered = v
	var anchor = _anchor_pos if _anchor_pos != Vector3.ZERO else _group_center()
	_issue_slots(anchor, _last_facing)


func _process(delta):
	if members.is_empty():
		return
	# Advance moving anchor toward destination
	if _anchor_pos.distance_to(_last_target) > 0.01 and _anchor_speed > 0.0:
		_anchor_pos = _anchor_pos.move_toward(_last_target, _anchor_speed * delta)
		_update_slot_targets()
	# Speed cap timer
	_speed_timer += delta
	if _speed_timer >= SPEED_CAP_INTERVAL:
		_speed_timer = 0.0
		_apply_speed_cap()


func _update_slot_targets():
	var to_eject: Array = []
	for unit in _slot_offsets:
		if not is_instance_valid(unit):
			continue
		if unit.is_in_group("garrisoned"):
			continue
		if _is_loading(unit):
			to_eject.append(unit)
			continue
		var new_slot = _anchor_pos + _slot_offsets[unit]
		new_slot.y = _last_target.y
		var old_slot = _slot_positions.get(unit, new_slot + Vector3.ONE * 999.0)
		if old_slot.distance_to(new_slot) > ANCHOR_MOVE_THRESHOLD:
			_slot_positions[unit] = new_slot
			unit.action = Moving.new(new_slot)
	for unit in to_eject:
		on_member_died(unit)


func _compute_anchor_speed() -> float:
	var min_base := INF
	for unit in members:
		if not is_instance_valid(unit) or unit.is_in_group("bolstering"):
			continue
		var mv = unit.find_child("Movement")
		if mv != null:
			min_base = minf(min_base, mv._base_speed)
	if min_base == INF:
		return 0.0
	return min_base * (0.9 if scattered else 1.0)


func _apply_speed_cap():
	var min_base := INF
	for unit in members:
		if not is_instance_valid(unit) or unit.is_in_group("bolstering"):
			continue
		var mv = unit.find_child("Movement")
		if mv != null:
			min_base = minf(min_base, mv._base_speed)
	if min_base == INF:
		return
	var cap = min_base * (0.9 if scattered else 1.0)
	_anchor_speed = cap
	for unit in members:
		if not is_instance_valid(unit) or unit.is_in_group("bolstering"):
			continue
		var mv = unit.find_child("Movement")
		if mv != null:
			mv.speed = cap


func _issue_slots(target: Vector3, facing: Vector3):
	facing.y = 0.0
	if facing.length() < 0.01:
		facing = -Vector3.FORWARD
	facing = facing.normalized()
	var right = facing.cross(Vector3.UP).normalized()
	var spacing = SLOT_SPACING_SCATTERED if scattered else SLOT_SPACING

	var valid = members.filter(func(u): return is_instance_valid(u) and not u.is_in_group("garrisoned"))
	if valid.is_empty():
		return

	_slot_positions.clear()
	_slot_offsets.clear()

	if formation_type == Type.BOX:
		_issue_box(valid, target, facing, right, spacing)
	elif formation_type == Type.COLUMN:
		_issue_line(valid, target, facing, right, spacing, false)
	else:
		_issue_line(valid, target, facing, right, spacing, true)


func _issue_line(units: Array, target: Vector3, facing: Vector3, right: Vector3, spacing: float, wide: bool):
	var n = units.size()
	var cols: int
	if wide:
		cols = maxi(1, roundi(sqrt(float(n) * 2.0)))
	else:
		cols = maxi(1, roundi(sqrt(float(n) * 0.5)))
	var rows = ceili(float(n) / cols)

	var sorted = units.duplicate()
	sorted.sort_custom(func(a, b): return _line_priority(a) < _line_priority(b))

	var idx = 0
	for r in range(rows):
		for c in range(cols):
			if idx >= n:
				break
			var pos = (
				target
				- facing * (r * spacing)
				+ right * ((c - (cols - 1) / 2.0) * spacing)
			)
			pos.y = target.y
			var unit = sorted[idx]
			if not _is_loading(unit):
				var offset = pos - target
				offset.y = 0.0
				_slot_offsets[unit] = offset
				_slot_positions[unit] = pos
				unit.action = Moving.new(pos)
			idx += 1


func _issue_box(units: Array, target: Vector3, facing: Vector3, right: Vector3, spacing: float):
	var n = units.size()
	var cols = maxi(2, ceili(sqrt(float(n))))
	var rows = ceili(float(n) / cols)

	var front: Array = []
	var sides: Array = []
	var interior: Array = []
	var rear: Array = []

	for r in range(rows):
		for c in range(cols):
			if r * cols + c >= n:
				continue
			var pos = (
				target
				- facing * (r * spacing)
				+ right * ((c - (cols - 1) / 2.0) * spacing)
			)
			pos.y = target.y
			if r == 0:
				front.append(pos)
			elif r == rows - 1 and rows > 1:
				rear.append(pos)
			elif c == 0 or c == cols - 1:
				sides.append(pos)
			else:
				interior.append(pos)

	var infantry = units.filter(func(u): return u.type == "infantry")
	var cavalry = units.filter(func(u): return u.type == "cavalry" or u.type == "flag_commander")
	var mid = units.filter(func(u): return u.type in ["archer", "siege", "supply_train"])
	var engineers = units.filter(func(u): return u.type == "engineer")

	var leftover_u: Array = []
	var leftover_s: Array = []
	_pair_assign(infantry, front, leftover_u, leftover_s)
	_pair_assign(cavalry, sides, leftover_u, leftover_s)
	_pair_assign(mid, interior, leftover_u, leftover_s)
	_pair_assign(engineers, rear, leftover_u, leftover_s)

	var oc = mini(leftover_u.size(), leftover_s.size())
	for i in range(oc):
		_slot_positions[leftover_u[i]] = leftover_s[i]

	for unit in _slot_positions:
		if _is_loading(unit):
			continue
		var slot = _slot_positions[unit]
		var offset = slot - target
		offset.y = 0.0
		_slot_offsets[unit] = offset
		unit.action = Moving.new(slot)


func _pair_assign(units: Array, slots: Array, leftover_u: Array, leftover_s: Array):
	var count = mini(units.size(), slots.size())
	for i in range(count):
		_slot_positions[units[i]] = slots[i]
	for i in range(count, units.size()):
		leftover_u.append(units[i])
	for i in range(count, slots.size()):
		leftover_s.append(slots[i])


func _line_priority(unit) -> int:
	return _LINE_PRIORITY.get(unit.type, 99)


func _is_loading(unit) -> bool:
	return (
		unit.action is LoadingIntoGarrison
		or unit.action is LoadingIntoCrew
		or unit.action is ApproachingExternalCrew
	)


func _release_unit(unit):
	if not is_instance_valid(unit):
		return
	var mv = unit.find_child("Movement")
	if mv != null and not unit.is_in_group("bolstering"):
		mv.recompute_speed()
	if unit.is_in_group("in_formation"):
		unit.remove_from_group("in_formation")


func _group_center() -> Vector3:
	var valid = members.filter(func(u): return is_instance_valid(u))
	if valid.is_empty():
		return Vector3.ZERO
	var sum = Vector3.ZERO
	for u in valid:
		sum += u.global_position
	return sum / float(valid.size())
