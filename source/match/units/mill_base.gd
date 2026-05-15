extends "res://source/match/units/Structure.gd"

const WAGON_CARGO = {
	"res://source/match/units/grain_mill.tscn": {"food": 50},
	"res://source/match/units/lumber_mill.tscn": {"wood": 50},
	"res://source/match/units/stone_mill.tscn": {"stone": 50},
}
const WAGON_SPAWN_INTERVAL = 30.0

var _spawn_timer = null


func _ready():
	await super()
	add_to_group("mills")
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = WAGON_SPAWN_INTERVAL
	_spawn_timer.timeout.connect(_spawn_wagon)
	add_child(_spawn_timer)
	_spawn_timer.start()


func _spawn_wagon():
	if not is_constructed():
		return
	var wagon_scene = load("res://source/match/units/supply_wagon_auto.tscn")
	var wagon = wagon_scene.instantiate()
	var scene_path = get_script().resource_path.replace(".gd", ".tscn")
	wagon.cargo = WAGON_CARGO.get(scene_path, {})
	MatchSignals.setup_and_spawn_unit.emit(wagon, global_transform.translated(Vector3(2, 0, 0)), player)
