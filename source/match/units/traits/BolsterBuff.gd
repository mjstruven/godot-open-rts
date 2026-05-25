extends Node

const SPEED_MULTIPLIER = 0.1

var _original_base_speed: float = 0.0
var _marker: MeshInstance3D = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _movement = _unit.find_child("Movement")


func _ready():
	_unit.add_to_group("bolstering")
	if _movement != null:
		_original_base_speed = _movement._base_speed
		_movement._base_speed = _original_base_speed * SPEED_MULTIPLIER
		_movement.recompute_speed()
	print("[BolsterBuff] READY: _movement=", _movement != null, " orig_base=", _original_base_speed, " new_base=", _movement._base_speed if _movement != null else -1.0, " speed=", _movement.speed if _movement != null else -1.0)
	_marker = _create_marker()


func _exit_tree():
	print("[BolsterBuff] EXIT_TREE: _movement_valid=", is_instance_valid(_movement), " _original_base_speed=", _original_base_speed)
	if is_instance_valid(_unit):
		_unit.remove_from_group("bolstering")
		_unit.set_meta("bolster_cooldown_end_ms", Time.get_ticks_msec() + 60000)
	if is_instance_valid(_movement):
		print("[BolsterBuff] EXIT_TREE base_BEFORE=", _movement._base_speed, " slow_contributors=", _movement._slow_contributors)
		_movement._base_speed = _original_base_speed
		_movement.recompute_speed()
		print("[BolsterBuff] EXIT_TREE base_AFTER=", _movement._base_speed, " speed_AFTER=", _movement.speed)
	if is_instance_valid(_marker):
		_marker.queue_free()
		_marker = null


func _create_marker() -> MeshInstance3D:
	var marker = MeshInstance3D.new()
	var mesh = ImmediateMesh.new()
	marker.mesh = mesh
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.BLACK
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	marker.material_override = mat
	var s: float = 0.15
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	mesh.surface_add_vertex(Vector3(-s, 0.0, -s))
	mesh.surface_add_vertex(Vector3(s, 0.0, s))
	mesh.surface_end()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	mesh.surface_add_vertex(Vector3(-s, 0.0, s))
	mesh.surface_add_vertex(Vector3(s, 0.0, -s))
	mesh.surface_end()
	marker.position = Vector3(0.0, 0.0, 0.0)
	_unit.add_child(marker)
	return marker
