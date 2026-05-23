extends "res://source/match/units/Unit.gd"

const ATTACK_MIN_RANGE: float = 5.0
const ATTACK_AOE_DAMAGE: int = 25
const MIN_CREW_TO_FUNCTION: int = 2

const BallistaWaitingForTargets = preload(
	"res://source/match/units/actions/BallistaWaitingForTargets.gd"
)


func _ready():
	await super()
	add_to_group("siege_units")
	add_to_group("neutral_siege")
	set_meta("attack_min_range", ATTACK_MIN_RANGE)
	set_meta("attack_aoe_damage", ATTACK_AOE_DAMAGE)
	action = BallistaWaitingForTargets.new()
	var ecm = find_child("ExternalCrewManager")
	if ecm != null:
		ecm.crew_changed.connect(_on_crew_changed)
	action_changed.connect(_on_action_changed)


func _on_action_changed(new_action) -> void:
	if new_action != null:
		return
	if not is_inside_tree():
		return
	var ecm = find_child("ExternalCrewManager")
	if ecm != null and ecm.crew_count() >= MIN_CREW_TO_FUNCTION:
		action = BallistaWaitingForTargets.new()


func _on_crew_changed(new_count: int) -> void:
	if new_count < MIN_CREW_TO_FUNCTION:
		action_queue.clear()
		action = BallistaWaitingForTargets.new()


func _set_action(action_node):
	if action_node != null and not (action_node is BallistaWaitingForTargets):
		var ecm = find_child("ExternalCrewManager")
		if ecm != null and ecm.crew_count() < MIN_CREW_TO_FUNCTION:
			action_node.queue_free()
			if is_instance_valid(player):
				MatchSignals.alert_message.emit(player, "Needs at least 2 engineers to operate")
			return
	super(action_node)


func _handle_unit_death():
	var ecm = find_child("ExternalCrewManager")
	if ecm != null:
		for eng in ecm.get_all_engineers():
			if is_instance_valid(eng):
				eng.hp = 0
	super()


func refresh_player_color():
	var geo = find_child("Geometry")
	if geo == null:
		return
	var mat = player.get_color_material() if is_instance_valid(player) else null
	for child in geo.find_children("*", "MeshInstance3D", true, false):
		child.material_override = mat


func reset_player_color():
	var geo = find_child("Geometry")
	if geo == null:
		return
	for child in geo.find_children("*", "MeshInstance3D", true, false):
		child.material_override = null
