extends "res://source/match/units/Unit.gd"

const Circle3D = preload("res://source/generic-scenes-and-nodes/3d/Circle3D.gd")
const SupplyTrainWagonScene = preload("res://source/match/units/supply_train_wagon.tscn")

const WAGON_SPAWN_INTERVAL = 30.0
const AURA_RADIUS = 15.0
const MAX_WAGONS = 4
const MAX_BONUS = 0.40

var _wagon_count: int = 0
var _active_wagons: Array = []
var _buffed_units: Array = []
var _has_ever_had_wagons: bool = false
var _wagon_timer: float = 0.0
var _buff_scan_timer: float = 0.0
var _heal_timer: float = 0.0
var _blink_timer: float = 0.0
var _blink_visible: bool = true
var _range_circle = null

@onready var _bonus_label: Label3D = find_child("BonusLabel")
@onready var _red_dot: Label3D = find_child("RedDot")


func _ready():
	await super()
	add_to_group("supply_trains")
	_range_circle = Circle3D.new()
	_range_circle.radius = AURA_RADIUS
	_range_circle.width = 3.0
	_range_circle.color = Color.WHITE
	_range_circle.render_priority = 1
	add_child(_range_circle)
	_range_circle.hide()
	_update_bonus_label()
	_update_red_dot()
	MatchSignals.unit_selected.connect(_on_any_unit_selected)
	MatchSignals.unit_deselected.connect(_on_any_unit_deselected)


func _process(delta):
	_wagon_timer += delta
	if _wagon_timer >= WAGON_SPAWN_INTERVAL:
		_wagon_timer = 0.0
		_try_spawn_wagon()

	_buff_scan_timer += delta
	if _buff_scan_timer >= 0.5:
		_buff_scan_timer = 0.0
		_scan_buffs()

	_heal_timer += delta
	if _heal_timer >= 1.0:
		_heal_timer = 0.0
		_heal_nearby()

	if _wagon_count == 0 and _has_ever_had_wagons:
		_blink_timer += delta
		if _blink_timer >= 0.5:
			_blink_timer = 0.0
			_blink_visible = not _blink_visible
			_red_dot.visible = _blink_visible


func _exit_tree():
	for unit in _buffed_units.duplicate():
		_release_unit(unit)
	if MatchSignals.unit_selected.is_connected(_on_any_unit_selected):
		MatchSignals.unit_selected.disconnect(_on_any_unit_selected)
	if MatchSignals.unit_deselected.is_connected(_on_any_unit_deselected):
		MatchSignals.unit_deselected.disconnect(_on_any_unit_deselected)


func on_wagon_arrived(wagon):
	if wagon in _active_wagons:
		_active_wagons.erase(wagon)
	_wagon_count = mini(_wagon_count + 1, MAX_WAGONS)
	_has_ever_had_wagons = true
	_update_bonus_label()
	_update_red_dot()
	_scan_buffs()


func _on_wagon_tree_exited(wagon):
	if wagon in _active_wagons and not wagon._arrived:
		_active_wagons.erase(wagon)
		_wagon_count = maxi(_wagon_count - 1, 0)
		_update_bonus_label()
		_update_red_dot()
		_scan_buffs()


func _try_spawn_wagon():
	var capitals = get_tree().get_nodes_in_group("capitals").filter(
		func(c): return c.player == player and c.is_constructed()
	)
	if capitals.is_empty():
		return
	capitals.sort_custom(func(a, b):
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	var capital = capitals[0]
	var wagon = SupplyTrainWagonScene.instantiate()
	wagon.target_train = self
	wagon.tree_exited.connect(_on_wagon_tree_exited.bind(wagon))
	_active_wagons.append(wagon)
	MatchSignals.setup_and_spawn_unit.emit(wagon, capital.global_transform, player)


func _scan_buffs():
	var bonus = _current_bonus()
	var nearby = _get_nearby_friendly_units()
	for unit in _buffed_units.duplicate():
		if not is_instance_valid(unit) or unit not in nearby:
			_release_unit(unit)
	for unit in nearby:
		if not is_instance_valid(unit):
			continue
		if not unit.has_meta("st_owner"):
			_claim_unit(unit, bonus)
		elif unit.get_meta("st_owner") == self:
			_update_unit_buff(unit, bonus)
		else:
			var other = unit.get_meta("st_owner")
			if not is_instance_valid(other):
				unit.remove_meta("st_owner")
				_claim_unit(unit, bonus)
			elif bonus > other._current_bonus():
				other.release_unit_external(unit)
				_claim_unit(unit, bonus)


func _claim_unit(unit, bonus: float):
	if unit not in _buffed_units:
		_buffed_units.append(unit)
		var mv = unit.find_child("Movement")
		if mv != null:
			unit.set_meta("st_base_speed", mv.speed)
		if unit.attack_interval != null:
			unit.set_meta("st_base_interval", unit.attack_interval)
	unit.set_meta("st_owner", self)
	_update_unit_buff(unit, bonus)


func _update_unit_buff(unit, bonus: float):
	var mv = unit.find_child("Movement")
	if mv != null and unit.has_meta("st_base_speed"):
		mv.speed = unit.get_meta("st_base_speed") * (1.0 + bonus)
	if unit.attack_interval != null and unit.has_meta("st_base_interval"):
		unit.attack_interval = unit.get_meta("st_base_interval") * (1.0 - bonus)


func _release_unit(unit):
	_buffed_units.erase(unit)
	if not is_instance_valid(unit):
		return
	if unit.has_meta("st_owner") and unit.get_meta("st_owner") == self:
		unit.remove_meta("st_owner")
	var mv = unit.find_child("Movement")
	if mv != null and unit.has_meta("st_base_speed"):
		mv.speed = unit.get_meta("st_base_speed")
		unit.remove_meta("st_base_speed")
	if unit.attack_interval != null and unit.has_meta("st_base_interval"):
		unit.attack_interval = unit.get_meta("st_base_interval")
		unit.remove_meta("st_base_interval")


func release_unit_external(unit):
	_release_unit(unit)


func _heal_nearby():
	if _wagon_count == 0:
		return
	for unit in _get_nearby_friendly_units():
		if is_instance_valid(unit) and unit.hp != null and unit.hp_max != null and unit.hp < unit.hp_max:
			unit.hp = mini(unit.hp + 1, unit.hp_max)


func _get_nearby_friendly_units() -> Array:
	return get_tree().get_nodes_in_group("units").filter(func(u):
		return (
			is_instance_valid(u)
			and u != self
			and u.player == player
			and global_position.distance_to(u.global_position) <= AURA_RADIUS
			and not _is_supply_unit(u)
		)
	)


func _is_supply_unit(u) -> bool:
	var path = u.get_script().resource_path
	return (
		path.ends_with("supply_wagon_auto.gd")
		or path.ends_with("supply_train_wagon.gd")
		or path.ends_with("supply_train.gd")
	)


func _current_bonus() -> float:
	return float(_wagon_count) / float(MAX_WAGONS) * MAX_BONUS


func _update_bonus_label():
	if _bonus_label == null:
		return
	var pct = int(_current_bonus() * 100.0)
	_bonus_label.text = "+%d%%" % pct


func _update_red_dot():
	if _red_dot == null:
		return
	if _wagon_count > 0 or not _has_ever_had_wagons:
		_red_dot.visible = false
		_blink_timer = 0.0
		_blink_visible = true


func _on_any_unit_selected(unit):
	if not is_instance_valid(unit):
		return
	if unit == self or (unit.player == player and global_position.distance_to(unit.global_position) <= AURA_RADIUS):
		_range_circle.show()


func _on_any_unit_deselected(_unit):
	var selected_nearby = get_tree().get_nodes_in_group("selected_units").any(func(u):
		return (
			is_instance_valid(u)
			and u.player == player
			and (u == self or global_position.distance_to(u.global_position) <= AURA_RADIUS)
		)
	)
	if not selected_nearby:
		_range_circle.hide()
