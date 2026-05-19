extends Node

# All registered TerrainRegion nodes in the current map.
var _regions: Array = []

# unit (Area3D) -> Array of TerrainRegion nodes currently overlapping it.
var _unit_regions: Dictionary = {}

# unit -> snapshot of stats taken just before terrain modifiers were applied.
# { "speed": float|null, "sight_range": float, "attack_range": float|null, "attack_damage": int|null }
var _unit_original_stats: Dictionary = {}


# ── Registration (called by TerrainRegion._ready / _exit_tree) ──────────────

func register_region(region) -> void:
	if not region in _regions:
		_regions.append(region)


func unregister_region(region) -> void:
	_regions.erase(region)
	for unit in _unit_regions.keys():
		_unit_regions[unit].erase(region)
		if is_instance_valid(unit) and unit.is_inside_tree():
			_update_unit_mods(unit)


# ── Area3D signal handlers (called by TerrainRegion) ────────────────────────

func _on_unit_entered_region(unit, region) -> void:
	if not _unit_regions.has(unit):
		_unit_regions[unit] = []
	if not region in _unit_regions[unit]:
		_unit_regions[unit].append(region)
	_update_unit_mods(unit)
	GameLogger.debug(GameLogger.Category.COMBAT, "Terrain entered", {
		"unit": unit.name,
		"terrain": TerrainRegion.Type.keys()[region.terrain_type],
	})


func _on_unit_exited_region(unit, region) -> void:
	if not _unit_regions.has(unit):
		return
	_unit_regions[unit].erase(region)
	if not is_instance_valid(unit) or not unit.is_inside_tree():
		_unit_regions.erase(unit)
		_unit_original_stats.erase(unit)
		return
	_update_unit_mods(unit)
	GameLogger.debug(GameLogger.Category.COMBAT, "Terrain exited", {
		"unit": unit.name,
		"terrain": TerrainRegion.Type.keys()[region.terrain_type],
	})


# ── Public query API ─────────────────────────────────────────────────────────

func get_terrain_type_at(world_pos: Vector3) -> int:
	for region in _regions:
		if not is_instance_valid(region):
			continue
		if region.terrain_type == TerrainRegion.Type.ELEVATED:
			continue
		if region.contains_point(world_pos):
			return region.terrain_type
	return TerrainRegion.Type.GRASSLAND


func get_elevation_at(world_pos: Vector3) -> int:
	for region in _regions:
		if not is_instance_valid(region):
			continue
		if region.terrain_type == TerrainRegion.Type.ELEVATED and region.contains_point(world_pos):
			return 1
	return 0


func is_forest_at(world_pos: Vector3) -> bool:
	for region in _regions:
		if not is_instance_valid(region):
			continue
		if region.terrain_type == TerrainRegion.Type.FOREST and region.contains_point(world_pos):
			return true
	return false


func get_movement_modifier_at(world_pos: Vector3) -> float:
	var mult = 1.0
	for region in _regions:
		if not is_instance_valid(region) or not region.contains_point(world_pos):
			continue
		match region.terrain_type:
			TerrainRegion.Type.FOREST:
				mult *= 0.9
			TerrainRegion.Type.ROCKY:
				mult *= 0.95
			TerrainRegion.Type.FORD:
				mult *= 0.7
	return mult


func get_regions() -> Array:
	return _regions.duplicate()


func is_valid_mill_placement(world_pos: Vector3, mill_type: String) -> bool:
	var terrain: int = get_terrain_type_at(world_pos)
	match mill_type:
		"grain_mill":
			return terrain == TerrainRegion.Type.GRASSLAND
		"lumber_mill":
			if terrain == TerrainRegion.Type.FOREST:
				return false
			return _is_adjacent_to_terrain_type(world_pos, TerrainRegion.Type.FOREST, 8.0)
		"stone_mill":
			if terrain == TerrainRegion.Type.ROCKY:
				return false
			return _is_adjacent_to_terrain_type(world_pos, TerrainRegion.Type.ROCKY, 8.0)
	return true


func _is_adjacent_to_terrain_type(world_pos: Vector3, terrain_type: int, radius: float) -> bool:
	var qx: float = world_pos.x
	var qz: float = world_pos.z
	for region in _regions:
		if not is_instance_valid(region):
			continue
		if region.terrain_type != terrain_type:
			continue
		# World-space AABB half-extents (scale × local box half-size of 5)
		var sx: float = region.global_transform.basis.x.length() * 5.0
		var sz: float = region.global_transform.basis.z.length() * 5.0
		var cx: float = region.global_position.x
		var cz: float = region.global_position.z
		# Distance from query point to nearest point on the region's AABB
		var dx: float = max(0.0, abs(qx - cx) - sx)
		var dz: float = max(0.0, abs(qz - cz) - sz)
		if sqrt(dx * dx + dz * dz) <= radius:
			return true
	return false


# ── Internal modifier apply/restore ─────────────────────────────────────────

func _update_unit_mods(unit) -> void:
	_restore_stats(unit)

	var regions: Array = _unit_regions.get(unit, [])
	regions = regions.filter(func(r): return is_instance_valid(r))
	if regions.is_empty():
		_unit_regions.erase(unit)
		return

	var movement = unit.find_child("Movement")
	_unit_original_stats[unit] = {
		"speed": movement.speed if movement != null else null,
		"sight_range": unit.sight_range,
		"attack_range": unit.attack_range,
		"attack_damage": unit.attack_damage,
	}

	var speed_mult = 1.0
	var sight_bonus = 0.0
	var range_bonus = 0.0
	var damage_mult = 1.0
	var in_forest = false

	for region in regions:
		match region.terrain_type:
			TerrainRegion.Type.FOREST:
				speed_mult *= 0.9
				in_forest = true
			TerrainRegion.Type.ROCKY:
				speed_mult *= 0.95
				damage_mult *= 0.95
			TerrainRegion.Type.FORD:
				speed_mult *= 0.7
			TerrainRegion.Type.ELEVATED:
				sight_bonus += 3.0
				# +2 range for ranged units (attack_range > 2 tiles means ranged)
				if unit.attack_range != null and unit.attack_range > 2.0:
					range_bonus += 2.0

	var orig = _unit_original_stats[unit]
	if movement != null and orig["speed"] != null:
		movement.speed = orig["speed"] * speed_mult
	if orig["sight_range"] != null:
		unit.sight_range = orig["sight_range"] + sight_bonus
	if unit.attack_range != null and orig["attack_range"] != null:
		unit.attack_range = orig["attack_range"] + range_bonus
	if unit.attack_damage != null and orig["attack_damage"] != null:
		unit.attack_damage = max(1, int(orig["attack_damage"] * damage_mult))

	if in_forest:
		unit.add_to_group("units_in_forest")


func _restore_stats(unit) -> void:
	if not _unit_original_stats.has(unit):
		unit.remove_from_group("units_in_forest")
		return
	var orig = _unit_original_stats[unit]
	if is_instance_valid(unit) and unit.is_inside_tree():
		var movement = unit.find_child("Movement")
		if movement != null and orig["speed"] != null:
			movement.speed = orig["speed"]
		if orig["sight_range"] != null:
			unit.sight_range = orig["sight_range"]
		if unit.attack_range != null and orig["attack_range"] != null:
			unit.attack_range = orig["attack_range"]
		if unit.attack_damage != null and orig["attack_damage"] != null:
			unit.attack_damage = orig["attack_damage"]
	unit.remove_from_group("units_in_forest")
	_unit_original_stats.erase(unit)
