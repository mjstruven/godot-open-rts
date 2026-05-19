extends Node

const RALLY_RADIUS = 8.0
const RALLY_DURATION = 15.0
const RALLY_COOLDOWN = 45.0

var _cooldown_remaining: float = 0.0
var _active: bool = false

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


func _process(delta):
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = max(0.0, _cooldown_remaining - delta)


func is_ready() -> bool:
	return _cooldown_remaining <= 0.0 and not _active


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func activate():
	if not is_ready():
		return
	_active = true

	var buffed_units = []
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or u == _unit or not u.is_inside_tree():
			continue
		if u.player != _unit.player:
			continue
		var movement = u.find_child("Movement")
		if movement == null:
			continue
		var dist = _unit.global_position_yless.distance_to(u.global_position_yless)
		if dist > RALLY_RADIUS:
			continue
		movement.speed *= 1.2
		if u.attack_interval != null:
			u.attack_interval /= 1.2
		buffed_units.append(u)
		_flash_unit(u)

	GameLogger.info(GameLogger.Category.COMBAT, "Rally activated", {
		"units_buffed": buffed_units.size(),
		"radius": RALLY_RADIUS,
	})

	get_tree().create_timer(RALLY_DURATION).timeout.connect(func():
		_restore_buffs(buffed_units)
		_active = false
		_cooldown_remaining = RALLY_COOLDOWN
	)


func _restore_buffs(buffed_units: Array):
	for u in buffed_units:
		if not is_instance_valid(u) or not u.is_inside_tree():
			continue
		var movement = u.find_child("Movement")
		if movement != null:
			movement.speed /= 1.2
		if u.attack_interval != null:
			u.attack_interval *= 1.2


func _flash_unit(u):
	var geom = u.find_child("Geometry")
	if geom == null:
		return
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.0, 1.0)
	for child in geom.get_children():
		if child is MeshInstance3D:
			child.material_override = mat
	get_tree().create_timer(0.35).timeout.connect(func():
		if not is_instance_valid(geom):
			return
		for child in geom.get_children():
			if child is MeshInstance3D:
				child.material_override = null
	)
