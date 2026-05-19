extends Node

const Moving = preload("res://source/match/units/actions/Moving.gd")

enum Type { LINE, BOX }

const SLOT_SPACING = 1.0
const SLOT_SPACING_SCATTERED = 1.5
const ARRIVAL_THRESHOLD = 1.1
const SPEED_CAP_INTERVAL = 0.1
const SETTLE_DELAY = 0.5

const _LINE_PRIORITY = {
	"cavalry": 0,
	"infantry": 1,
	"archer": 2,
	"siege": 3,
	"supply_train": 4,
	"engineer": 5,
}

var formation_type: int = Type.LINE
var scattered: bool = false
var members: Array = []

var _slot_positions: Dictionary = {}
var _base_speeds: Dictionary = {}
var _moving: bool = false
var _wide_issued: bool = false
var _last_target: Vector3 = Vector3.ZERO
var _last_facing: Vector3 = -Vector3.FORWARD
var _speed_timer: float = 0.0
var _settle_timer: float = 0.0


func setup(units: Array):
	members = units.duplicate()
	for unit in members:
		var mv = unit.find_child("Movement")
		if mv != null:
			_base_speeds[unit] = mv.speed
		unit.add_to_group("in_formation")


func disband():
	for unit in members.duplicate():
		_release_unit(unit)
	members.clear()
	_slot_positions.clear()
	_base_speeds.clear()
	_moving = false


func issue_move(target: Vector3):
	_last_target = target
	_moving = true
	_wide_issued = false
	_settle_timer = 0.0

	var center = _group_center()
	var dir = target - center
	dir.y = 0.0
	if dir.length() > 0.1:
		_last_facing = dir.normalized()

	_issue_slots(target, _last_facing, false)


func on_member_died(unit):
	members.erase(unit)
	_slot_positions.erase(unit)
	_base_speeds.erase(unit)
	if unit.is_in_group("in_formation"):
		unit.remove_from_group("in_formation")
	if members.is_empty():
		disband()


func set_formation_type(t: int):
	formation_type = t
	_issue_slots(_last_target, _last_facing, _wide_issued and formation_type == Type.LINE)


func set_scattered(v: bool):
	scattered = v
	_issue_slots(_last_target, _last_facing, _wide_issued and formation_type == Type.LINE)


func _process(delta):
	if members.is_empty():
		return

	_speed_timer += delta
	if _speed_timer >= SPEED_CAP_INTERVAL:
		_speed_timer = 0.0
		_apply_speed_cap()

	if _moving and not _wide_issued and formation_type == Type.LINE:
		_settle_timer += delta
		if _settle_timer >= SETTLE_DELAY and _all_near_slots():
			_wide_issued = true
			_moving = false
			_issue_slots(_last_target, _last_facing, true)


func _apply_speed_cap():
	var min_base := INF
	for unit in members:
		if is_instance_valid(unit) and unit in _base_speeds:
			min_base = minf(min_base, _base_speeds[unit])
	if min_base == INF:
		return
	var cap = min_base * (0.9 if scattered else 1.0)
	for unit in members:
		if not is_instance_valid(unit):
			continue
		var mv = unit.find_child("Movement")
		if mv != null:
			mv.speed = cap


func _all_near_slots() -> bool:
	for unit in members:
		if not is_instance_valid(unit):
			continue
		var slot = _slot_positions.get(unit)
		if slot == null:
			continue
		if unit.global_position.distance_to(slot) > ARRIVAL_THRESHOLD:
			return false
	return true


func _issue_slots(target: Vector3, facing: Vector3, wide: bool):
	facing.y = 0.0
	if facing.length() < 0.01:
		facing = -Vector3.FORWARD
	facing = facing.normalized()
	var right = facing.cross(Vector3.UP).normalized()
	var spacing = SLOT_SPACING_SCATTERED if scattered else SLOT_SPACING

	var valid = members.filter(func(u): return is_instance_valid(u))
	if valid.is_empty():
		return

	_slot_positions.clear()

	if formation_type == Type.LINE:
		_issue_line(valid, target, facing, right, spacing, wide)
	else:
		_issue_box(valid, target, facing, right, spacing)


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
	var cavalry = units.filter(func(u): return u.type == "cavalry")
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
		unit.action = Moving.new(_slot_positions[unit])


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


func _release_unit(unit):
	if not is_instance_valid(unit):
		return
	var mv = unit.find_child("Movement")
	if mv != null and unit in _base_speeds:
		mv.speed = _base_speeds[unit]
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
