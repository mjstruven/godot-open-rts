extends "res://source/match/units/actions/Action.gd"

const TrebuchetAttackingWhileInRange = preload(
	"res://source/match/units/actions/TrebuchetAttackingWhileInRange.gd"
)
const TREB_MIN_RANGE = 7.0
const POLL_INTERVAL = 0.15

var _target_unit = null
var _poll_timer = null
var _sub_action = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


static func is_applicable(source_unit, target_unit) -> bool:
	var ecm = source_unit.find_child("ExternalCrewManager")
	if ecm == null or ecm.crew_count() < 2:
		return false
	return (
		source_unit.attack_range != null
		and "player" in target_unit
		and source_unit.player != target_unit.player
		and not target_unit.is_in_group("neutral_siege")
		and (
			not target_unit.has_meta("crew_siege_unit")
			or target_unit.get_meta("crew_siege_unit") != source_unit
		)
		and target_unit.movement_domain in source_unit.attack_domains
	)


func _init(target_unit):
	_target_unit = target_unit


func _ready():
	if not is_instance_valid(_target_unit) or not _target_unit.is_inside_tree():
		queue_free()
		return
	_target_unit.tree_exited.connect(func(): queue_free())
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.timeout.connect(_advance)
	add_child(_poll_timer)
	_poll_timer.start()
	_advance()


func _is_in_range() -> bool:
	if not is_instance_valid(_target_unit):
		return false
	var dist = _unit.global_position_yless.distance_to(_target_unit.global_position_yless)
	return dist >= TREB_MIN_RANGE and dist <= _unit.attack_range


func _advance():
	if not is_inside_tree():
		return
	if not is_instance_valid(_target_unit) or not _target_unit.is_inside_tree():
		queue_free()
		return
	if _sub_action != null:
		return
	var dist = _unit.global_position_yless.distance_to(_target_unit.global_position_yless)
	if dist < TREB_MIN_RANGE:
		queue_free()
		return
	var pack_state = _unit.get_pack_state()
	var in_range = _is_in_range()
	if in_range and pack_state == "UNPACKED":
		_poll_timer.stop()
		_sub_action = TrebuchetAttackingWhileInRange.new(_target_unit)
		_sub_action.tree_exited.connect(_on_sub_action_finished)
		add_child(_sub_action)
		_unit.action_updated.emit()
	elif in_range and pack_state == "PACKED":
		_unit.set_pack_target(1.0)
	elif not in_range and pack_state == "UNPACKED":
		_unit.set_pack_target(0.0)
	# else TRANSITIONING — keep polling


func _on_sub_action_finished():
	if not is_inside_tree():
		return
	_sub_action = null
	_unit.action_updated.emit()
	_poll_timer.start(POLL_INTERVAL)
	_advance()
