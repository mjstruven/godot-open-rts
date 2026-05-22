extends "res://source/match/units/actions/Action.gd"

const ArcherAttackingWhileInRange = preload(
	"res://source/match/units/actions/ArcherAttackingWhileInRange.gd"
)
const SuppressZoneManagerScript = preload("res://source/match/SuppressZoneManager.gd")

const RANGE_BONUS = 2.0
const INTERVAL_MULTIPLIER = 2.0 / 3.0
const MIN_RANGE = 1.0
const COOLDOWN_DURATION = 5.0

var _target_unit = null
var _attack_range_before: float = 0.0
var _attack_interval_before: float = 0.0
var _stats_boosted: bool = false
var _suppress_started: bool = false
var _is_attacking: bool = false

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


func _init(target_unit):
	_target_unit = target_unit


func _ready():
	var player = _unit.player
	if not player.has_resources({"wood": 1}):
		GameLogger.info(GameLogger.Category.COMBAT, "Suppress ended", {"reason": "no_wood"})
		_unit.remove_from_group("suppress_armed")
		MatchSignals.suppress_state_changed.emit(_unit, "idle")
		queue_free()
		return

	player.subtract_resources({"wood": 1})
	GameLogger.info(GameLogger.Category.ECONOMY, "Suppress wood cost", {
		"archers": 1, "wood_deducted": 1, "wood_remaining": player.wood
	})

	_unit.remove_from_group("suppress_armed")
	_unit.add_to_group("suppressing")

	var movement = _unit.find_child("Movement")
	if is_instance_valid(movement):
		movement.stop()

	_attack_range_before = _unit.attack_range
	_attack_interval_before = _unit.attack_interval
	_unit.attack_range = _attack_range_before + RANGE_BONUS
	_unit.attack_interval = _attack_interval_before * INTERVAL_MULTIPLIER
	_stats_boosted = true
	_suppress_started = true

	var zone_mgr = _get_zone_manager()
	if zone_mgr != null:
		zone_mgr.register_zone(self)

	_target_unit.tree_exited.connect(_on_target_removed)

	var range_check = Timer.new()
	range_check.timeout.connect(_try_start_attacking)
	add_child(range_check)
	range_check.start(1.0 / 60.0 * 10.0)

	_try_start_attacking()
	MatchSignals.suppress_state_changed.emit(_unit, "suppressing")


func _try_start_attacking():
	if _is_attacking:
		return
	if not is_instance_valid(_target_unit) or not _target_unit.is_inside_tree():
		return
	var dist = _unit.global_position_yless.distance_to(_target_unit.global_position_yless)
	if dist < MIN_RANGE or dist > _unit.attack_range:
		return
	_is_attacking = true
	var atk = ArcherAttackingWhileInRange.new(_target_unit)
	atk.tree_exited.connect(_on_attack_finished)
	add_child(atk)


func _on_attack_finished():
	_is_attacking = false


func _restore_stats():
	if _stats_boosted:
		_unit.attack_range = _attack_range_before
		_unit.attack_interval = _attack_interval_before
		_stats_boosted = false


func _on_target_removed():
	queue_free()


func get_zone_info() -> Dictionary:
	if not is_instance_valid(_target_unit) or not _target_unit.is_inside_tree():
		return {}
	var target_pos = _target_unit.global_position
	var archer_pos = _unit.global_position
	var dist = Vector2(archer_pos.x, archer_pos.z).distance_to(Vector2(target_pos.x, target_pos.z))
	return {"center": target_pos, "radius": _get_zone_radius(dist)}


func _get_zone_radius(dist: float) -> float:
	if dist <= 5.0:
		return ArcherAttackingWhileInRange.SCATTER_RADIUS_SMALL
	elif dist <= 8.0:
		return ArcherAttackingWhileInRange.SCATTER_RADIUS_MEDIUM
	else:
		return ArcherAttackingWhileInRange.SCATTER_RADIUS_LARGE


func _get_zone_manager():
	var match_node = _unit.find_parent("Match")
	if match_node == null:
		return null
	var mgr = match_node.get_node_or_null("SuppressZoneManager")
	if mgr == null:
		mgr = SuppressZoneManagerScript.new()
		mgr.name = "SuppressZoneManager"
		match_node.add_child(mgr)
	return mgr


func _exit_tree():
	_restore_stats()
	if _suppress_started and is_instance_valid(_unit):
		_unit.remove_from_group("suppressing")
		var match_node = _unit.find_parent("Match")
		if match_node != null:
			var zone_mgr = match_node.get_node_or_null("SuppressZoneManager")
			if zone_mgr != null:
				zone_mgr.unregister_zone(self)
		_unit.set_meta(
			"suppress_cooldown_until_ms",
			Time.get_ticks_msec() + int(COOLDOWN_DURATION * 1000)
		)
		GameLogger.info(GameLogger.Category.COMBAT, "Suppress ended", {"reason": "exited"})
		MatchSignals.suppress_state_changed.emit(_unit, "idle")
