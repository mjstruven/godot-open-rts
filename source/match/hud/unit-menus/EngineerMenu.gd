extends GridContainer

const GrainMillUnit = preload("res://source/match/units/grain_mill.tscn")
const LumberMillUnit = preload("res://source/match/units/lumber_mill.tscn")
const StoneMillUnit = preload("res://source/match/units/stone_mill.tscn")
const TownCenterUnit = preload("res://source/match/units/town_center.tscn")
const CapitalUnit = preload("res://source/match/units/capital.tscn")


func _on_place_grain_mill_button_pressed():
	MatchSignals.place_structure.emit(GrainMillUnit)


func _on_place_lumber_mill_button_pressed():
	MatchSignals.place_structure.emit(LumberMillUnit)


func _on_place_stone_mill_button_pressed():
	MatchSignals.place_structure.emit(StoneMillUnit)


func _on_place_town_center_button_pressed():
	MatchSignals.place_structure.emit(TownCenterUnit)


func _on_place_capital_button_pressed():
	MatchSignals.place_structure.emit(CapitalUnit)
