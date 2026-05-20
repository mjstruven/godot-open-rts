extends StaticBody3D

@onready var _collision_shape = find_child("CollisionShape3D")


func _ready():
	input_event.connect(_on_input_event)


func update_shape(reference_mesh):
	_collision_shape.shape = reference_mesh.create_trimesh_shape()


func _on_input_event(_camera, event, _click_position, _click_normal, _shape_idx):
	print("[P2.2] _on_input_event fired, type=", event.get_class())
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and event.pressed
	):
		print("[P2.2] right-click received at ", event.position)
		var hit: Variant = _raycast_terrain(event.position)
		print("[P2.2] emitting terrain_targeted with ", hit)
		MatchSignals.terrain_targeted.emit(hit)


func _raycast_terrain(mouse_pos: Vector2) -> Variant:
	const RAY_LENGTH: float = 2000.0
	const TERRAIN_SURFACE_LAYER: int = 16  # physics layer 5

	var camera: Camera3D = get_viewport().get_camera_3d()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_end: Vector3 = ray_origin + camera.project_ray_normal(mouse_pos) * RAY_LENGTH
	print("[P2.2] ray_origin=", ray_origin, " ray_end=", ray_end)

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var vp_space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	print("[P2.2] space==vp_space: ", (space == vp_space),
		" space=", space, " collision_mask=", TERRAIN_SURFACE_LAYER)

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		ray_origin, ray_end
	)
	query.collision_mask = TERRAIN_SURFACE_LAYER
	query.hit_back_faces = false

	var result: Dictionary = space.intersect_ray(query)
	print("[P2.2] raycast result=", result)

	if not result.is_empty():
		return result["position"]

	return Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_end - ray_origin)
