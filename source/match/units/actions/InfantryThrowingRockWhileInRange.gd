extends "res://source/match/units/actions/Action.gd"

const Circle3D = preload("res://source/generic-scenes-and-nodes/3d/Circle3D.gd")
const RANGE_CHECK_INTERVAL = 1.0 / 60.0 * 10.0
const MIN_RANGE = 1.0
const MAX_RANGE = 2.0
const FLIGHT_TIME = 0.6
const ROCK_SIZE = Vector3(0.08, 0.08, 0.08)
const ROCK_COLOR = Color(0.5, 0.5, 0.5)
const IMPACT_RADIUS = 0.5
const SCATTER_RADIUS_SMALL = 0.1875
const SCATTER_RADIUS_MEDIUM = 0.375
const SCATTER_RADIUS_LARGE = 0.65625

var _target_unit = null
var _one_shot_timer = null
var _range_check_timer = null
var _scatter_circle = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


func _init(target_unit):
	_target_unit = target_unit


func _ready():
	if not _unit.is_in_group("garrisoned"):
		queue_free()
		return
	if _teardown_if_out_of_range():
		return
	_target_unit.tree_exited.connect(_on_target_unit_removed)
	_setup_one_shot_timer()
	_setup_range_check_timer()
	if not _unit.has_meta("next_attack_availability_time"):
		_unit.set_meta(
			"next_attack_availability_time",
			Time.get_ticks_msec() + int(randf() * _unit.attack_interval * 1000.0)
		)
	_schedule_shot()


func _exit_tree():
	if is_instance_valid(_scatter_circle):
		_scatter_circle.queue_free()
		_scatter_circle = null


func _setup_one_shot_timer():
	_one_shot_timer = Timer.new()
	_one_shot_timer.one_shot = true
	_one_shot_timer.timeout.connect(_throw_rock)
	add_child(_one_shot_timer)


func _setup_range_check_timer():
	_range_check_timer = Timer.new()
	_range_check_timer.timeout.connect(_teardown_if_out_of_range)
	add_child(_range_check_timer)
	_range_check_timer.start(RANGE_CHECK_INTERVAL)


func _schedule_shot():
	var now = Time.get_ticks_msec()
	var next_time = _unit.get_meta("next_attack_availability_time", now)
	if next_time > now:
		_one_shot_timer.start((next_time - now) / 1000.0)
	else:
		_throw_rock()


func _throw_rock():
	if not _unit.is_in_group("garrisoned"):
		queue_free()
		return
	if _teardown_if_out_of_range():
		return
	_unit.set_meta(
		"next_attack_availability_time",
		Time.get_ticks_msec() + int(_unit.attack_interval * 1000.0)
	)

	var target_pos = _target_unit.global_position
	var thrower_pos = _unit.global_position
	var dist = Vector2(thrower_pos.x, thrower_pos.z).distance_to(Vector2(target_pos.x, target_pos.z))

	var scatter_radius = _get_scatter_radius(dist)
	var angle = randf() * TAU
	var scatter_dist = sqrt(randf()) * scatter_radius
	var offset = Vector2(cos(angle), sin(angle)) * scatter_dist
	var landing_point = target_pos + Vector3(offset.x, 0.0, offset.y)
	landing_point.y = 0.0

	var match_node = _unit.find_parent("Match")

	if is_instance_valid(_scatter_circle):
		_scatter_circle.queue_free()
	var circle = Circle3D.new()
	circle.radius = scatter_radius
	circle.width = 5.0
	circle.color = Color(0.6, 0.6, 0.6, 0.6)
	match_node.add_child(circle)
	circle.global_position = Vector3(target_pos.x, 0.01, target_pos.z)
	_scatter_circle = circle

	var rock_root = Node3D.new()
	var rock_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = ROCK_SIZE
	rock_mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = ROCK_COLOR
	rock_mesh.material_override = mat
	rock_root.add_child(rock_mesh)
	match_node.add_child(rock_root)
	rock_root.global_position = thrower_pos

	var tree = get_tree()
	var lp = landing_point
	var damage = _unit.attack_damage
	var impact_r = IMPACT_RADIUS
	var in_forest = TerrainManager.is_forest_at(thrower_pos)
	var host_tower = _unit.get_meta("garrison_of") if _unit.has_meta("garrison_of") else null

	var tween = match_node.create_tween()
	tween.tween_property(rock_root, "global_position", lp, FLIGHT_TIME)
	tween.tween_callback(func():
		rock_root.queue_free()
		var closest = null
		var closest_dist = INF
		for u in tree.get_nodes_in_group("units"):
			if not is_instance_valid(u):
				continue
			if is_instance_valid(host_tower) and u == host_tower:
				continue
			var d = Vector2(u.global_position.x, u.global_position.z).distance_to(
				Vector2(lp.x, lp.z)
			)
			if d <= impact_r and (closest == null or d < closest_dist):
				closest_dist = d
				closest = u
		if closest != null:
			var effective_damage = damage
			if not in_forest and TerrainManager.is_forest_at(lp):
				effective_damage = 0
			if closest.is_in_group("bolstering"):
				effective_damage = int(effective_damage * 0.1)
			if closest.is_in_group("garrisoned"):
				effective_damage = int(effective_damage * 0.5)
			closest.hp -= effective_damage
	)

	_schedule_shot()


func _get_scatter_radius(distance: float) -> float:
	if distance <= 5.0:
		return SCATTER_RADIUS_SMALL
	elif distance <= 8.0:
		return SCATTER_RADIUS_MEDIUM
	else:
		return SCATTER_RADIUS_LARGE


func _get_origin_yless() -> Vector3:
	if _unit.has_meta("garrison_of"):
		return _unit.get_meta("garrison_of").global_position_yless
	return _unit.global_position_yless


func _teardown_if_out_of_range() -> bool:
	if not _unit.is_in_group("garrisoned"):
		queue_free()
		return true
	var dist = _get_origin_yless().distance_to(_target_unit.global_position_yless)
	print("[TOWERATK] InfantryThrow teardown check: dist=%.2f (min=%.1f max=%.1f)" % [dist, MIN_RANGE, MAX_RANGE])
	if dist > MAX_RANGE or dist < MIN_RANGE:
		queue_free()
		return true
	return false


func _on_target_unit_removed():
	queue_free()
