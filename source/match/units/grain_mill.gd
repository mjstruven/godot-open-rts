extends "res://source/match/units/mill_base.gd"

const Circle3D = preload("res://source/generic-scenes-and-nodes/3d/Circle3D.gd")

var _cultivation_rings: Array = []


func _ready():
	await super()
	MatchSignals.unit_selected.connect(_on_unit_selected)
	MatchSignals.unit_deselected.connect(_on_unit_deselected)


func _on_unit_selected(unit) -> void:
	if unit != self:
		return
	_show_cultivation_rings()


func _on_unit_deselected(unit) -> void:
	if unit != self:
		return
	_hide_cultivation_rings()


func _show_cultivation_rings() -> void:
	_hide_cultivation_rings()
	var sel := find_child("Selection")
	if sel == null:
		return
	var current_r := CultivationManager.get_current_radius(self)
	if current_r > 0.1:
		var ring1 = _make_ring(current_r, Color(0.90, 0.75, 0.20, 0.60))
		sel.add_child(ring1)
		_cultivation_rings.append(ring1)
	var ring2 = _make_ring(CultivationManager.MAX_RADIUS, Color(0.90, 0.75, 0.20, 0.20))
	sel.add_child(ring2)
	_cultivation_rings.append(ring2)


func _hide_cultivation_rings() -> void:
	for ring in _cultivation_rings:
		if is_instance_valid(ring):
			ring.queue_free()
	_cultivation_rings.clear()


func _make_ring(r: float, ring_color: Color):
	var ring = Circle3D.new()
	ring.radius = r
	ring.width = 2.0
	ring.color = ring_color
	ring.render_priority = 3
	return ring
