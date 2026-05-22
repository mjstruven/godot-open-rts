extends "res://source/match/units/actions/Action.gd"

const ArcherAttackingWhileInRange = preload(
	"res://source/match/units/actions/ArcherAttackingWhileInRange.gd"
)
const SuppressZoneManagerScript = preload("res://source/match/SuppressZoneManager.gd")

const SUPPRESS_DURATION = 25.0
const GRACE_DURATION = 5.0
const RANGE_BONUS = 2.0
const INTERVAL_MULTIPLIER = 2.0 / 3.0  # 50% faster = 4s from 6s base
const MIN_RANGE = 1.0

var _target_unit = null
var _auto_refresh: bool = false
var _attack_range_before: float = 0.0
var _attack_interval_before: float = 0.0
var _stats_boosted: bool = false
var _suppress_started: bool = false
var _naturally_ended: bool = false
var _is_attacking: bool = false
var _start_time: float = 0.0
var _suppress_timer: Timer = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


func _init(target_unit, auto_refresh: bool = false):
	_target_unit = target_unit
	_auto_refresh = auto_refresh


func _ready():
	var player = _unit.player
	if not player.has_resources({"wood": 1}):
		GameLogger.info(GameLogger.Category.COMBAT, "Suppress ended", {
			"reason": "no_wood", "duration_actual": 0.0
		})
		MatchSignals.suppress_state_changed.emit(_unit, "idle", false)
		queue_free()
		return

	player.subtract_resources({"wood": 1})
	GameLogger.info(GameLogger.Category.ECONOMY, "Suppress wood cost", {
		"archers": 1, "wood_deducted": 1, "wood_remaining": player.wood
	})

	_unit.remove_from_group("suppress_armed")
	_unit.add_to_group("suppressing")

	_attack_range_before = _unit.attack_range
	_attack_interval_before = _unit.attack_interval
	_unit.attack_range = _attack_range_before + RANGE_BONUS
	_unit.attack_interval = _attack_interval_before * INTERVAL_MULTIPLIER
	_stats_boosted = true
	_start_time = Time.get_ticks_msec() / 1000.0
	_suppress_started = true

	var zone_mgr = _get_zone_manager()
	if zone_mgr != null:
		zone_mgr.register_zone(self)

	_target_unit.tree_exited.connect(_on_target_removed)

	_suppress_timer = Timer.new()
	_suppress_timer.one_shot = true
	_suppress_timer.timeout.connect(_on_suppress_duration_elapsed)
	add_child(_suppress_timer)
	_suppress_timer.start(SUPPRESS_DURATION)

	var range_check = Timer.new()
	range_check.timeout.connect(_try_start_attacking)
	add_child(range_check)
	range_check.start(1.0 / 60.0 * 10.0)

	_try_start_attacking()
	MatchSignals.suppress_state_changed.emit(_unit, "suppressing", _auto_refresh)


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
	# range_check timer will retry if target is back in range


func _on_suppress_duration_elapsed():
	if not is_inside_tree():
		return
	var duration_actual = Time.get_ticks_msec() / 1000.0 - _start_time
	_end_suppress("duration", duration_actual)


func _end_suppress(reason: String, duration: float):
	_restore_stats()
	_unit.remove_from_group("suppressing")
	GameLogger.info(GameLogger.Category.COMBAT, "Suppress ended", {
		"reason": reason, "duration_actual": duration
	})
	_naturally_ended = true
	MatchSignals.suppress_state_changed.emit(_unit, "grace", _auto_refresh)

	if _auto_refresh:
		var tree = get_tree()
		var unit_ref = _unit
		tree.create_timer(GRACE_DURATION).timeout.connect(func():
			if not is_instance_valid(unit_ref) or not unit_ref.is_inside_tree():
				return
			if not unit_ref.player.has_resources({"wood": 1}):
				MatchSignals.suppress_state_changed.emit(unit_ref, "idle", false)
				return
			unit_ref.add_to_group("suppress_armed")
			unit_ref.set_meta("suppress_auto_refresh", true)
			MatchSignals.suppress_state_changed.emit(unit_ref, "armed", true)
			unit_ref.action = null
		)
	else:
		MatchSignals.suppress_state_changed.emit(_unit, "idle", false)

	queue_free()


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
	if _suppress_started:
		_unit.remove_from_group("suppressing")
		if is_instance_valid(_unit):
			var match_node = _unit.find_parent("Match")
			if match_node != null:
				var zone_mgr = match_node.get_node_or_null("SuppressZoneManager")
				if zone_mgr != null:
					zone_mgr.unregister_zone(self)
	if _suppress_started and not _naturally_ended:
		var duration = Time.get_ticks_msec() / 1000.0 - _start_time
		GameLogger.info(GameLogger.Category.COMBAT, "Suppress ended", {
			"reason": "canceled", "duration_actual": duration
		})
		MatchSignals.suppress_state_changed.emit(_unit, "idle", false)
