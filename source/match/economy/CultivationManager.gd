extends Node

const EXPANSION_INTERVAL = 30.0
const EXPANSION_PER_TICK = 2.5
const MAX_RADIUS = 20.0
const BASE_FOOD_CARGO = 15
const MAX_FOOD_CARGO = 30
const GRAIN_MILL_EXCLUSION_RADIUS = 20.0

var _mill_data: Dictionary = {}
var _orphan_disks: Array = []
var _timer = null


func _ready():
	_timer = Timer.new()
	_timer.wait_time = EXPANSION_INTERVAL
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_timer.start()


func register_mill(mill) -> void:
	if _mill_data.has(mill):
		return
	var disk = _create_disk(mill.global_position)
	_mill_data[mill] = {"radius": 0.0, "disk": disk}


func unregister_mill(mill) -> void:
	if not _mill_data.has(mill):
		return
	var data = _mill_data[mill]
	_mill_data.erase(mill)
	var r = data["radius"]
	var disk = data["disk"]
	if r > 0.0 and is_instance_valid(disk):
		_orphan_disks.append({"disk": disk, "radius": r})
	elif is_instance_valid(disk):
		disk.queue_free()


func has_mill(mill) -> bool:
	return _mill_data.has(mill)


func get_current_radius(mill) -> float:
	if not _mill_data.has(mill):
		return 0.0
	return float(_mill_data[mill]["radius"])


func get_food_cargo(mill) -> int:
	var r: float = get_current_radius(mill)
	var t: float = r / MAX_RADIUS
	var amount: float = lerpf(float(BASE_FOOD_CARGO), float(MAX_FOOD_CARGO), t)
	var bonus: float = _get_manor_bonus(mill)
	return maxi(1, roundi(amount * bonus))


func _tick() -> void:
	var mill_keys := _mill_data.keys()
	for mill in mill_keys:
		if not is_instance_valid(mill):
			_mill_data.erase(mill)
			continue
		var data = _mill_data[mill]
		data["radius"] = minf(float(data["radius"]) + EXPANSION_PER_TICK, MAX_RADIUS)
		_update_disk_scale(data["disk"], float(data["radius"]))

	var to_remove := []
	for entry in _orphan_disks:
		if not is_instance_valid(entry["disk"]):
			to_remove.append(entry)
			continue
		entry["radius"] = maxf(0.0, float(entry["radius"]) - EXPANSION_PER_TICK)
		if float(entry["radius"]) <= 0.0:
			entry["disk"].queue_free()
			to_remove.append(entry)
		else:
			_update_disk_scale(entry["disk"], float(entry["radius"]))
	for entry in to_remove:
		_orphan_disks.erase(entry)


func _create_disk(world_pos: Vector3):
	var scene = get_tree().current_scene
	if scene == null:
		return null
	var cyl := CylinderMesh.new()
	cyl.height = 0.02
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.radial_segments = 48
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.78, 0.65, 0.25, 0.45)
	mat.render_priority = 3
	var inst := MeshInstance3D.new()
	inst.mesh = cyl
	inst.material_override = mat
	inst.scale = Vector3(0.01, 1.0, 0.01)
	scene.add_child(inst)
	inst.global_position = Vector3(world_pos.x, 0.02, world_pos.z)
	return inst


func _update_disk_scale(disk, radius: float) -> void:
	if not is_instance_valid(disk):
		return
	var s := maxf(0.01, radius)
	disk.scale = Vector3(s, 1.0, s)


func _get_manor_bonus(mill) -> float:
	if not is_instance_valid(mill):
		return 1.0
	var mill_pos = mill.global_position * Vector3(1, 0, 1)
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.player != mill.player:
			continue
		var script = unit.get_script()
		if script == null or not script.resource_path.ends_with("manor.gd"):
			continue
		if not unit.has_method("is_constructed") or not unit.is_constructed():
			continue
		var dist = (unit.global_position * Vector3(1, 0, 1)).distance_to(mill_pos)
		if dist <= mill.radius + 2.0:
			return 1.1
	return 1.0
