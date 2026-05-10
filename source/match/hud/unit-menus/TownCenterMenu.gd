extends GridContainer

const InfantryUnit = preload("res://source/match/units/infantry.tscn")
const ArcherUnit = preload("res://source/match/units/archer.tscn")
const CavalryUnit = preload("res://source/match/units/cavalry.tscn")

var unit = null


func _on_produce_infantry_button_pressed():
	unit.production_queue.produce(InfantryUnit)


func _on_produce_archer_button_pressed():
	unit.production_queue.produce(ArcherUnit)


func _on_produce_cavalry_button_pressed():
	unit.production_queue.produce(CavalryUnit)
