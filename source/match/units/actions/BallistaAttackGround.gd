extends "res://source/match/units/actions/Action.gd"

const BallistaAttackingWhileInRange = preload(
	"res://source/match/units/actions/BallistaAttackingWhileInRange.gd"
)

const FLIGHT_TIME = 0.7
const BOLT_SIZE = Vector3(0.12, 0.12, 0.5)
const BOLT_COLOR = Color(0.25, 0.22, 0.18)

var _target_pos: Vector3
var _delay_timer = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


func _init(target_pos: Vector3):
	_target_pos = target_pos


func _ready():
	var ecm = _unit.find_child("ExternalCrewManager")
	if ecm == null or ecm.crew_count() < 2:
		queue_free()
		return
	var now = Time.get_ticks_msec()
	var next = _unit.get_meta("next_attack_availability_time", now)
	if next > now:
		_delay_timer = Timer.new()
		_delay_timer.one_shot = true
		_delay_timer.wait_time = (next - now) / 1000.0
		_delay_timer.timeout.connect(_launch_bolt)
		add_child(_delay_timer)
		_delay_timer.start()
	else:
		_launch_bolt()


func _launch_bolt():
	if not is_instance_valid(_unit):
		queue_free()
		return
	_unit.set_meta(
		"next_attack_availability_time",
		Time.get_ticks_msec() + int(_unit.attack_interval * 1000.0)
	)
	var from_pos = _unit.global_position
	var to_pos = Vector3(_target_pos.x, 0.0, _target_pos.z)

	var match_node = _unit.find_parent("Match")
	var bolt_root = Node3D.new()
	var bolt_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = BOLT_SIZE
	bolt_mesh.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = BOLT_COLOR
	bolt_mesh.material_override = mat
	bolt_root.add_child(bolt_mesh)
	match_node.add_child(bolt_root)
	bolt_root.global_position = from_pos
	var flat_target = Vector3(to_pos.x, from_pos.y, to_pos.z)
	if from_pos.distance_to(flat_target) > 0.01:
		bolt_root.look_at(flat_target, Vector3.UP)

	var tree = get_tree()
	var src_unit = _unit
	var a_pos = from_pos
	var lp = to_pos
	var l_dmg: int = _unit.attack_damage
	var a_dmg: int = _unit.get_meta("attack_aoe_damage", l_dmg)
	var action_self = self

	var tween = match_node.create_tween()
	tween.tween_property(bolt_root, "global_position", to_pos, FLIGHT_TIME)
	tween.tween_callback(func():
		bolt_root.queue_free()
		BallistaAttackingWhileInRange._apply_damage(
			tree, src_unit, a_pos, lp, l_dmg, a_dmg,
			BallistaAttackingWhileInRange.AOE_RADIUS, BallistaAttackingWhileInRange.LINE_WIDTH
		)
		if is_instance_valid(action_self):
			action_self.queue_free()
	)
