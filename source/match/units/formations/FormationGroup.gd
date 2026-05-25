extends Node

const Moving = preload("res://source/match/units/actions/Moving.gd")

enum Type { COLUMN, BOX, RANKS }

const SLOT_SPACING = 1.5
const SLOT_SPACING_SCATTERED = 1.75
const SPEED_CAP_INTERVAL = 0.1

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
var _last_target: Vector3 = Vector3.ZERO
var _last_facing: Vector3 = -Vector3.FORWARD
var _speed_timer: float = 0.0
var _tick_log_timer: float = 0.0
var _debug_caller: String = ""


func setup(units: Array):
	members = units.duplicate()
	for unit in members:
		unit.add_to_group("in_formation")


func disband():
	for unit in members.duplicate():
		_release_unit(unit)
	members.clear()
	_slot_positions.clear()


func issue_move(target: Vector3):
	var _stack = get_stack()
	var _caller = _stack[1] if _stack.size() > 1 else {"source": "?", "function": "?", "line": -1}
	print("[FormCaller] issue_move called by %s:%s:%d target=%s" % [_caller["source"], _caller["function"], _caller["line"], target])
	_last_target = target
	var center = _group_center()
	var dir = target - center
	dir.y = 0.0
	if dir.length() > 0.1:
		_last_facing = dir.normalized()
	print("[FormAnchor] source=issue_move anchor=stored_target value=%s" % target)
	_debug_caller = "issue_move"
	_issue_slots(target, _last_facing)
	# DEBUG: confirm slot spread after assignment
	for unit in _slot_positions:
		var slot = _slot_positions[unit]
		print(
			"[FormMove] unit=%s type=%s slot_pos=%s group_target=%s dist_slot_to_target=%.2f"
			% [unit.name, unit.get("type"), slot, target, slot.distance_to(target)]
		)


func on_member_died(unit):
	members.erase(unit)
	_slot_positions.erase(unit)
	if unit.is_in_group("in_formation"):
		unit.remove_from_group("in_formation")
	if members.is_empty():
		disband()


func set_formation_type(t: int):
	formation_type = t
	var anchor: Vector3
	var anchor_source: String
	if _last_target != Vector3.ZERO:
		anchor = _last_target
		anchor_source = "stored_last_target"
	else:
		anchor = _group_center()
		anchor_source = "live_center_fallback"
	print("[FormReform] set_formation_type type=%d anchor_source=%s anchor=%s _last_target=%s" % [t, anchor_source, anchor, _last_target])
	print("[FormAnchor] source=set_formation_type anchor=%s value=%s" % [anchor_source, anchor])
	_debug_caller = "set_formation_type"
	_issue_slots(anchor, _last_facing)


func set_scattered(v: bool):
	scattered = v
	var anchor: Vector3
	var anchor_source: String
	if _last_target != Vector3.ZERO:
		anchor = _last_target
		anchor_source = "stored_last_target"
	else:
		anchor = _group_center()
		anchor_source = "live_center_fallback"
	print("[FormReform] set_scattered scattered=%s anchor_source=%s anchor=%s _last_target=%s" % [v, anchor_source, anchor, _last_target])
	print("[FormAnchor] source=set_scattered anchor=%s value=%s" % [anchor_source, anchor])
	_debug_caller = "set_scattered"
	_issue_slots(anchor, _last_facing)


func _process(delta):
	if members.is_empty():
		return
	_speed_timer += delta
	if _speed_timer >= SPEED_CAP_INTERVAL:
		_speed_timer = 0.0
		_apply_speed_cap()
	# DEBUG: once-per-second action/position tick
	_tick_log_timer += delta
	if _tick_log_timer >= 1.0:
		_tick_log_timer = 0.0
		for unit in members:
			if not is_instance_valid(unit):
				continue
			var slot = _slot_positions.get(unit)
			var act_name := "null"
			if unit.action != null:
				var sc = unit.action.get_script()
				act_name = sc.resource_path.get_file() if sc != null else unit.action.get_class()
			var dist: float = unit.global_position.distance_to(slot) if slot != null else -1.0
			print(
				"[FormTick] unit=%s current_action=%s slot_pos=%s actual_pos=%s dist_to_slot=%.2f"
				% [unit.name, act_name, slot, unit.global_position, dist]
			)


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
	for unit in members:
		if not is_instance_valid(unit) or unit.is_in_group("bolstering"):
			continue
		var mv = unit.find_child("Movement")
		if mv != null:
			mv.speed = cap


func _issue_slots(target: Vector3, facing: Vector3):
	print("[FormIssue] caller=%s anchor=%s facing=%s" % [_debug_caller, target, facing])
	_debug_caller = ""
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
			_slot_positions[unit] = pos
			# DEBUG: confirm per-unit slot assignment
			print("[FormSlot] unit=%s assigned Moving to %s" % [unit.name, pos])
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
		# DEBUG: confirm per-unit slot assignment
		print("[FormSlot] unit=%s assigned Moving to %s" % [unit.name, _slot_positions[unit]])
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
