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
		var hit: Variant = _raycast_terrain(event.position)
		MatchSignals.terrain_targeted.emit(hit)


func _raycast_terrain(mouse_pos: Vector2) -> Variant:
	const RAY_LENGTH: float = 2000.0
	const TERRAIN_SURFACE_LAYER: int = 16  # physics layer 5

	var camera: Camera3D = get_viewport().get_camera_3d()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_end: Vector3 = ray_origin + camera.project_ray_normal(mouse_pos) * RAY_LENGTH

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		ray_origin, ray_end
	)
	query.collision_mask = TERRAIN_SURFACE_LAYER
	query.hit_back_faces = false

	var result: Dictionary = space.intersect_ray(query)
	if not result.is_empty():
		return result["position"]

	return Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_end - ray_origin)
