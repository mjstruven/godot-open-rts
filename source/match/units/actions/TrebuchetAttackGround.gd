extends "res://source/match/units/actions/Action.gd"

const TrebuchetAttackingWhileInRange = preload(
	"res://source/match/units/actions/TrebuchetAttackingWhileInRange.gd"
)

const SCATTER_RADIUS_CLOSE = 1.0    # 7–13 (tunable)
const SCATTER_RADIUS_MID = 1.75    # 14–19 (tunable)
const SCATTER_RADIUS_FAR = 2.75    # 20–25 (tunable)
const SCATTER_RADIUS_MAX = 3.75    # 26–30 (tunable)
const AOE_RADIUS = 1.5
const FLIGHT_TIME = 1.5
const ARC_PEAK = 5.0
const INDICATOR_GREY = Color(0.5, 0.5, 0.5, 0.50)
const INDICATOR_RED = Color(0.85, 0.10, 0.10, 0.65)
const RED_PRE_FIRE_DURATION = 1.0
const ROCK_COLOR = Color(0.5, 0.5, 0.55)

var _target_pos: Vector3
var _scatter_pos: Vector3
var _indicator: MeshInstance3D = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


func _init(target_pos: Vector3):
	_target_pos = target_pos


func _ready():
	if _unit.get_pack_state() != "UNPACKED":
		queue_free()
		return
	var ecm = _unit.find_child("ExternalCrewManager")
	if ecm == null or ecm.crew_count() < 2:
		queue_free()
		return
	_begin_shot_cycle()


func _exit_tree():
	_cleanup_indicator()


func _begin_shot_cycle():
	_pick_scatter_pos()
	_create_indicator(INDICATOR_GREY)
	_schedule_shot()


func _pick_scatter_pos():
	var unit_pos = _unit.global_position
	var dist = Vector2(unit_pos.x, unit_pos.z).distance_to(Vector2(_target_pos.x, _target_pos.z))
	var scatter_radius = _get_scatter_radius(dist)
	var angle = randf() * TAU
	var scatter_dist = sqrt(randf()) * scatter_radius
	var offset = Vector2(cos(angle), sin(angle)) * scatter_dist
	_scatter_pos = Vector3(_target_pos.x + offset.x, 0.0, _target_pos.z + offset.y)


func _get_scatter_radius(dist: float) -> float:
	if dist <= 13.0:
		return SCATTER_RADIUS_CLOSE
	elif dist <= 19.0:
		return SCATTER_RADIUS_MID
	elif dist <= 25.0:
		return SCATTER_RADIUS_FAR
	else:
		return SCATTER_RADIUS_MAX


func _create_indicator(color: Color):
	var match_node = _unit.find_parent("Match")
	if match_node == null:
		return
	var mesh = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = AOE_RADIUS
	cylinder.bottom_radius = AOE_RADIUS
	cylinder.height = 0.01
	cylinder.radial_segments = 16
	mesh.mesh = cylinder
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.render_priority = 1
	mat.no_depth_test = true
	mesh.material_override = mat
	match_node.add_child(mesh)
	mesh.global_position = Vector3(_scatter_pos.x, 0.005, _scatter_pos.z)
	_indicator = mesh


func _set_indicator_color(color: Color):
	if is_instance_valid(_indicator) and _indicator.material_override != null:
		_indicator.material_override.albedo_color = color


func _cleanup_indicator():
	if is_instance_valid(_indicator):
		_indicator.queue_free()
	_indicator = null


func _schedule_shot():
	var now = Time.get_ticks_msec()
	var is_first = _unit.get_meta("treb_first_shot", false)
	if is_first:
		_unit.remove_meta("treb_first_shot")
		_set_indicator_color(INDICATOR_RED)
		_start_timer(5.0, _fire_shot)
		return
	var next = _unit.get_meta("next_attack_availability_time", now)
	if next <= now:
		_set_indicator_color(INDICATOR_RED)
		_start_timer(RED_PRE_FIRE_DURATION, _fire_shot)
	else:
		var remaining = (next - now) / 1000.0
		_start_timer(remaining, _on_reload_done)


func _on_reload_done():
	if not is_inside_tree():
		return
	_set_indicator_color(INDICATOR_RED)
	_start_timer(RED_PRE_FIRE_DURATION, _fire_shot)


func _fire_shot():
	if not is_inside_tree():
		return
	if _unit.get_pack_state() != "UNPACKED":
		queue_free()
		return
	var ecm = _unit.find_child("ExternalCrewManager")
	if ecm == null or ecm.crew_count() < 2:
		queue_free()
		return
	_unit.set_meta(
		"next_attack_availability_time",
		Time.get_ticks_msec() + int(_unit.attack_interval * 1000.0)
	)
	var from_pos: Vector3 = _unit.global_position
	var to_pos: Vector3 = _scatter_pos
	var indicator_to_fire = _indicator
	_indicator = null
	_launch_rock(from_pos, to_pos, indicator_to_fire)


func _launch_rock(from_pos: Vector3, to_pos: Vector3, indicator_to_remove: MeshInstance3D):
	var match_node = _unit.find_parent("Match")
	if match_node == null:
		if is_instance_valid(indicator_to_remove):
			indicator_to_remove.queue_free()
		return
	var rock = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	rock.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.albedo_color = ROCK_COLOR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rock.material_override = mat
	match_node.add_child(rock)
	rock.global_position = from_pos

	var tree = get_tree()
	var src = _unit
	var impact: Vector3 = to_pos
	var dmg: int = _unit.attack_damage
	var action_ref = self

	var arc_move = func(t: float) -> void:
		if not is_instance_valid(rock):
			return
		var xz_x = lerpf(from_pos.x, to_pos.x, t)
		var xz_z = lerpf(from_pos.z, to_pos.z, t)
		var arc_y = 4.0 * ARC_PEAK * t * (1.0 - t)
		rock.global_position = Vector3(xz_x, from_pos.y + arc_y, xz_z)

	var tween = match_node.create_tween()
	tween.tween_method(arc_move, 0.0, 1.0, FLIGHT_TIME)
	tween.tween_callback(func():
		if is_instance_valid(rock):
			rock.queue_free()
		if is_instance_valid(indicator_to_remove):
			indicator_to_remove.queue_free()
		TrebuchetAttackingWhileInRange._apply_aoe_damage(tree, src, impact, dmg)
		if is_instance_valid(action_ref) and action_ref.is_inside_tree():
			action_ref._on_rock_landed()
	)


func _on_rock_landed():
	if not is_inside_tree():
		return
	_begin_shot_cycle()


func _start_timer(wait_time: float, callback: Callable):
	var t = Timer.new()
	t.wait_time = wait_time
	t.one_shot = true
	add_child(t)
	t.timeout.connect(func():
		t.queue_free()
		callback.call()
	)
	t.start()
