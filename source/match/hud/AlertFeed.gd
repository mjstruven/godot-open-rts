extends VBoxContainer

const Human = preload("res://source/match/players/human/Human.gd")
const MAX_ALERTS = 6
const FADE_DURATION = 10.0

class Alert:
	var label: Label
	var age: float = 0.0

var _alerts: Array[Alert] = []
var _player = null
var _alerted_critical: Array = []  # units already warned at critical HP


func _ready():
	await MatchSignals.match_started
	var human_players = get_tree().get_nodes_in_group("players").filter(
		func(p): return p is Human
	)
	if human_players.is_empty():
		return
	_player = human_players[0]
	MatchSignals.unit_died.connect(_on_unit_died)
	MatchSignals.unit_damaged.connect(_on_unit_damaged)
	MatchSignals.unit_construction_finished.connect(_on_construction_finished)
	MatchSignals.unit_production_finished.connect(_on_production_finished)
	MatchSignals.alert_message.connect(_on_alert_message)


func _process(delta):
	for alert in _alerts.duplicate():
		alert.age += delta
		var alpha = clampf(1.0 - (alert.age / FADE_DURATION), 0.0, 1.0)
		alert.label.modulate.a = alpha
		if alert.age >= FADE_DURATION:
			alert.label.queue_free()
			_alerts.erase(alert)


func _on_unit_died(unit):
	if unit.player != _player:
		return
	var name_str = _unit_name(unit)
	_push("! %s lost" % name_str)


func _on_unit_damaged(unit):
	if unit.player != _player:
		return
	if unit.has_method("is_under_construction") and unit.is_under_construction():
		return
	if unit.hp <= unit.hp_max * 0.25 and not unit in _alerted_critical:
		_alerted_critical.append(unit)
		unit.tree_exited.connect(func(): _alerted_critical.erase(unit))
		_push("! %s critically wounded" % _unit_name(unit))


func _on_construction_finished(unit):
	if unit.player != _player:
		return
	_push("%s construction complete" % _unit_name(unit))


func _on_production_finished(unit, producer):
	if producer.player != _player:
		return
	_push("%s ready" % _unit_name(unit))


func _push(text: String):
	while _alerts.size() >= MAX_ALERTS:
		_alerts[0].label.queue_free()
		_alerts.remove_at(0)
	var lbl = Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(lbl)
	var alert = Alert.new()
	alert.label = lbl
	_alerts.append(alert)


func _on_alert_message(msg_player, text: String):
	if msg_player != _player:
		return
	_push(text)


func _unit_name(unit) -> String:
	if unit is PackedScene:
		return unit.resource_path.get_file().get_basename().replace("_", " ").capitalize()
	return unit.type.replace("_", " ").capitalize()
