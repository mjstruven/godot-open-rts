extends GridContainer

const InfantryUnit = preload("res://source/match/units/infantry.tscn")
const ArcherUnit = preload("res://source/match/units/archer.tscn")
const CavalryUnit = preload("res://source/match/units/cavalry.tscn")

var units = []


func _on_produce_infantry_button_pressed():
	_produce_distributed(InfantryUnit)


func _on_produce_archer_button_pressed():
	_produce_distributed(ArcherUnit)


func _on_produce_cavalry_button_pressed():
	_produce_distributed(CavalryUnit)


func _produce_distributed(prototype):
	var available = units.filter(func(u): return u.is_constructed())
	if available.is_empty():
		return
	var target = available.reduce(func(a, b):
		return a if a.production_queue.size() <= b.production_queue.size() else b
	)
	target.production_queue.produce(prototype)
