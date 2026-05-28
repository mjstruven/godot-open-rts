extends "res://source/match/units/actions/Action.gd"

const RANGE_CHECK_INTERVAL = 1.0 / 60.0 * 10.0
const FLIGHT_TIME = 0.7
const BOLT_SIZE = Vector3(0.12, 0.12, 0.5)
const BOLT_COLOR = Color(0.25, 0.22, 0.18)
const AOE_RADIUS = 4.0
const LINE_WIDTH = 0.5
const MIN_RANGE = 3.0

var _target_unit = null
var _one_shot_timer = null
var _range_check_timer = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _unit_movement_trait = _unit.find_child("Movement")


func _init(target_unit):
	_target_unit = target_unit


func _ready():
	if _teardown_if_out_of_range():
		return
	_target_unit.tree_exited.connect(_on_target_unit_removed)
	if _unit_movement_trait != null:
		_unit_movement_trait.passive_movement_started.connect(_on_passive_movement_started)
		_unit_movement_trait.passive_movement_finished.connect(_on_passive_movement_finished)
	_setup_one_shot_timer()
	_setup_range_check_timer()
	_schedule_shot()


func _physics_process(_delta):
	if _unit_movement_trait == null:
		_update_target_rotation()


func _setup_one_shot_timer():
	_one_shot_timer = Timer.new()
	_one_shot_timer.one_shot = true
	_one_shot_timer.timeout.connect(_fire_shot)
	add_child(_one_shot_timer)


func _setup_range_check_timer():
	_range_check_timer = Timer.new()
	_range_check_timer.timeout.connect(_teardown_if_out_of_range)
	add_child(_range_check_timer)
	_range_check_timer.start(RANGE_CHECK_INTERVAL)


func _update_target_rotation():
	var wp = _unit.global_position
	var tp = _target_unit.global_position
	_unit.target_rotation_y = atan2(wp.x - tp.x, wp.z - tp.z)


func _schedule_shot():
	var now = Time.get_ticks_msec()
	var next = _unit.get_meta("next_attack_availability_time", now)
	if next > now:
		_one_shot_timer.start((next - now) / 1000.0)
	else:
		_fire_shot()


func _fire_shot():
	if _teardown_if_out_of_range():
		return
	_unit.set_meta(
		"next_attack_availability_time",
		Time.get_ticks_msec() + int(_unit.attack_interval * 1000.0)
	)
	var from_pos = _unit.global_position
	var to_pos = _target_unit.global_position

	var match_node = _unit.find_parent("Match")
	var bolt_root = Node3D.new()
	var bolt_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = BOLT_SIZE
	bolt_mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = BOLT_COLOR
	bolt_mesh.material_override = mat
	bolt_root.add_child(bolt_mesh)
	match_node.add_child(bolt_root)
	bolt_root.global_position = from_pos
	var flat_target = Vector3(to_pos.x, from_pos.y, to_pos.z)
	if from_pos.distance_to(flat_target) > 0.01:
		bolt_root.look_at(flat_target, Vector3.UP)

	var tree = get_tree()
	var src_unit = _unit
	var a_pos = from_pos
	var lp = to_pos
	var l_dmg: int = _unit.attack_damage
	var a_dmg: int = _unit.get_meta("attack_aoe_damage", l_dmg)
	var a_radius: float = AOE_RADIUS
	var l_width: float = LINE_WIDTH

	var tween = match_node.create_tween()
	tween.tween_property(bolt_root, "global_position", to_pos, FLIGHT_TIME)
	tween.tween_callback(func():
		bolt_root.queue_free()
		_apply_damage(tree, src_unit, a_pos, lp, l_dmg, a_dmg, a_radius, l_width)
	)
	_schedule_shot()


func _teardown_if_out_of_range() -> bool:
	var dist = _unit.global_position_yless.distance_to(_target_unit.global_position_yless)
	if dist < MIN_RANGE or dist > _unit.attack_range:
		queue_free()
		return true
	return false


func _on_target_unit_removed():
	queue_free()


func _on_passive_movement_started():
	_one_shot_timer.stop()


func _on_passive_movement_finished():
	_update_target_rotation()
	_schedule_shot()


static func _apply_damage(
	tree: SceneTree,
	src_unit: Node,
	a_pos: Vector3,
	lp: Vector3,
	l_dmg: int,
	a_dmg: int,
	a_radius: float,
	l_width: float
) -> void:
	var ax2 = Vector2(a_pos.x, a_pos.z)
	var bx2 = Vector2(lp.x, lp.z)
	var ab2 = bx2 - ax2
	var ab2_sq: float = ab2.length_squared()
	var host_tower = null
	if is_instance_valid(src_unit) and src_unit.is_in_group("garrisoned") and src_unit.has_meta("garrison_of"):
		host_tower = src_unit.get_meta("garrison_of")

	for u in tree.get_nodes_in_group("units"):
		if not is_instance_valid(u) or u == src_unit:
			continue
		if u.has_meta("crew_siege_unit") and u.get_meta("crew_siege_unit") == src_unit:
			continue
		if is_instance_valid(host_tower) and u == host_tower:
			continue
		# Line pierce
		var px2 = Vector2(u.global_position.x, u.global_position.z)
		var ld: float
		if ab2_sq < 0.0001:
			ld = px2.distance_to(ax2)
		else:
			var ap2 = px2 - ax2
			var t2 = clamp(ap2.dot(ab2) / ab2_sq, 0.0, 1.0)
			ld = px2.distance_to(ax2 + ab2 * t2)
		if ld <= l_width:
			var ldmg_eff = int(l_dmg * 0.1) if u.is_in_group("bolstering") else l_dmg
			if u.is_in_group("garrisoned"):
				ldmg_eff = int(ldmg_eff * 0.5)
			u.hp -= ldmg_eff

	for u in tree.get_nodes_in_group("units"):
		if not is_instance_valid(u) or u == src_unit:
			continue
		if u.has_meta("crew_siege_unit") and u.get_meta("crew_siege_unit") == src_unit:
			continue
		if is_instance_valid(host_tower) and u == host_tower:
			continue
		var d2d = Vector2(u.global_position.x, u.global_position.z).distance_to(bx2)
		if d2d <= a_radius:
			var admg_eff = int(a_dmg * 0.1) if u.is_in_group("bolstering") else a_dmg
			if u.is_in_group("garrisoned"):
				admg_eff = int(admg_eff * 0.5)
			u.hp -= admg_eff
