extends "res://source/match/units/actions/Action.gd"

const Circle3D = preload("res://source/generic-scenes-and-nodes/3d/Circle3D.gd")
const RANGE_CHECK_INTERVAL = 1.0 / 60.0 * 10.0
const MIN_RANGE = 1.0
const FLIGHT_TIME = 0.6
const ARROW_LENGTH = 0.4
const ARROW_WIDTH = 0.03
const ARROW_COLOR = Color(0.706, 0.627, 0.471)
const IMPACT_RADIUS = 0.5
const SCATTER_RADIUS_SMALL = 1.0
const SCATTER_RADIUS_MEDIUM = 2.0
const SCATTER_RADIUS_LARGE = 3.5

var _target_unit = null
var _one_shot_timer = null
var _range_check_timer = null
var _scatter_circle = null

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
		_rotate_unit_towards_target()


func _exit_tree():
	if is_instance_valid(_scatter_circle):
		_scatter_circle.queue_free()
		_scatter_circle = null


func _setup_one_shot_timer():
	_one_shot_timer = Timer.new()
	_one_shot_timer.one_shot = true
	_one_shot_timer.timeout.connect(_fire_arrow)
	add_child(_one_shot_timer)


func _setup_range_check_timer():
	_range_check_timer = Timer.new()
	_range_check_timer.timeout.connect(_teardown_if_out_of_range)
	add_child(_range_check_timer)
	_range_check_timer.start(RANGE_CHECK_INTERVAL)


func _rotate_unit_towards_target():
	_unit.global_transform = _unit.global_transform.looking_at(
		Vector3(
			_target_unit.global_position.x,
			_unit.global_position.y,
			_target_unit.global_position.z
		),
		Vector3(0, 1, 0)
	)


func _schedule_shot():
	var now = Time.get_ticks_msec()
	var next_attack_availability_time = _unit.get_meta("next_attack_availability_time", now)
	if next_attack_availability_time > now:
		var delay_millis = next_attack_availability_time - now
		_one_shot_timer.start(delay_millis / 1000.0)
	else:
		_fire_arrow()


func _fire_arrow():
	if _teardown_if_out_of_range():
		return
	_unit.set_meta(
		"next_attack_availability_time",
		Time.get_ticks_msec() + int(_unit.attack_interval * 1000.0)
	)

	var target_pos = _target_unit.global_position
	var archer_pos = _unit.global_position
	var dist = Vector2(archer_pos.x, archer_pos.z).distance_to(Vector2(target_pos.x, target_pos.z))

	var scatter_radius = _get_scatter_radius(dist)
	var angle = randf() * TAU
	var scatter_dist = sqrt(randf()) * scatter_radius
	var offset = Vector2(cos(angle), sin(angle)) * scatter_dist
	var landing_point = target_pos + Vector3(offset.x, 0.0, offset.y)
	landing_point.y = 0.0

	GameLogger.debug(GameLogger.Category.COMBAT, "Arrow fired", {
		"archer": _unit.name,
		"target": _target_unit.name,
		"distance": dist,
		"scatter_radius": scatter_radius,
		"landing_point": str(landing_point)
	})

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

	var arrow_root = Node3D.new()
	var arrow_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(ARROW_WIDTH, ARROW_WIDTH, ARROW_LENGTH)
	arrow_mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = ARROW_COLOR
	arrow_mesh.material_override = mat
	arrow_root.add_child(arrow_mesh)
	match_node.add_child(arrow_root)
	arrow_root.global_position = archer_pos
	var flat_target = Vector3(landing_point.x, archer_pos.y, landing_point.z)
	if archer_pos.distance_to(flat_target) > 0.01:
		arrow_root.look_at(flat_target, Vector3.UP)

	var tween = match_node.create_tween()
	tween.tween_property(arrow_root, "global_position", landing_point, FLIGHT_TIME)

	var tree = get_tree()
	var lp = landing_point
	var damage = _unit.attack_damage
	var impact_r = IMPACT_RADIUS
	var archer_in_forest = TerrainManager.is_forest_at(_unit.global_position)
	tween.tween_callback(func():
		arrow_root.queue_free()
		var closest = null
		var closest_dist = INF
		for u in tree.get_nodes_in_group("units"):
			if not is_instance_valid(u):
				continue
			var d = Vector2(u.global_position.x, u.global_position.z).distance_to(
				Vector2(lp.x, lp.z)
			)
			if d <= impact_r and (closest == null or d < closest_dist):
				closest_dist = d
				closest = u
		if closest != null:
			var unit_name = closest.name
			var unit_script_file = closest.get_script().resource_path.get_file()
			var effective_damage = damage
			if not archer_in_forest and TerrainManager.is_forest_at(lp):
				effective_damage = 0
				GameLogger.debug(GameLogger.Category.COMBAT, "Arrow blocked by forest cover", {
					"landing_point": str(lp),
					"unit_hit": unit_name,
				})
			closest.hp -= effective_damage
			GameLogger.debug(GameLogger.Category.COMBAT, "Arrow impact", {
				"landing_point": str(lp),
				"unit_hit": unit_name,
				"damage": effective_damage
			})
			if not is_instance_valid(closest):
				GameLogger.balance("unit_killed", {
					"unit_type": unit_script_file,
					"killer_type": "archer",
					"game_time": str(GameLogger.get_match_time())
				})
			elif closest.hp <= 0:
				GameLogger.balance("unit_killed", {
					"unit_type": unit_script_file,
					"killer_type": "archer",
					"game_time": str(GameLogger.get_match_time())
				})
		else:
			GameLogger.debug(GameLogger.Category.COMBAT, "Arrow impact", {
				"landing_point": str(lp),
				"unit_hit": "none",
				"damage": 0
			})
	)

	_schedule_shot()


func _get_scatter_radius(distance: float) -> float:
	if distance <= 5.0:
		return SCATTER_RADIUS_SMALL
	elif distance <= 8.0:
		return SCATTER_RADIUS_MEDIUM
	else:
		return SCATTER_RADIUS_LARGE


func _teardown_if_out_of_range() -> bool:
	var dist = _unit.global_position_yless.distance_to(_target_unit.global_position_yless)
	if dist > _unit.attack_range or dist < MIN_RANGE:
		queue_free()
		return true
	return false


func _on_target_unit_removed():
	queue_free()


func _on_passive_movement_started():
	_one_shot_timer.stop()


func _on_passive_movement_finished():
	_rotate_unit_towards_target()
	_schedule_shot()
