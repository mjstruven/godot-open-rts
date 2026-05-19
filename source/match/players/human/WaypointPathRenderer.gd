extends Node3D

const LINE_Y_OFFSET = 0.5

var _mesh_instance: MeshInstance3D
var _mesh: ImmediateMesh


func _ready():
	_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	_mesh_instance.material_override = mat
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)


func _process(_delta):
	_mesh.clear_surfaces()
	var selected_units = get_tree().get_nodes_in_group("selected_units").filter(
		func(u): return u.is_in_group("controlled_units")
	)
	for unit in selected_units:
		if unit.action_queue.is_empty():
			continue
		var points: Array[Vector3] = []
		points.append(unit.global_position + Vector3(0, LINE_Y_OFFSET, 0))
		for entry in unit.action_queue:
			if entry.has("waypoint") and entry["waypoint"] != null:
				points.append((entry["waypoint"] as Vector3) + Vector3(0, LINE_Y_OFFSET, 0))
		if points.size() < 2:
			continue
		_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for p in points:
			_mesh.surface_add_vertex(p)
		_mesh.surface_end()
