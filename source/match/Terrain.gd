extends StaticBody3D

@onready var _collision_shape = find_child("CollisionShape3D")


func _ready():
	input_event.connect(_on_input_event)


func update_shape(reference_mesh):
	_collision_shape.shape = reference_mesh.create_trimesh_shape()


func _on_input_event(_camera, event, _click_position, _click_normal, _shape_idx):
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and event.pressed
	):
		var camera: Camera3D = get_viewport().get_camera_3d()
		var mouse_pos: Vector2 = event.position
		var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
		var ray_dir: Vector3 = camera.project_ray_normal(mouse_pos)
		var tvs = get_tree().get_first_node_in_group("terrain_visual_system")
		var hit: Variant = null
		if tvs != null:
			hit = tvs.get_terrain_ray_hit(ray_origin, ray_dir)
		if hit == null:
			hit = Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_dir)
		MatchSignals.terrain_targeted.emit(hit)
