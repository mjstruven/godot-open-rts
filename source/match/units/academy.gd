extends "res://source/match/units/Structure.gd"

const TYPE_NAMES = {
	"res://source/match/units/infantry.tscn": "Infantry",
	"res://source/match/units/archer.tscn": "Archer",
	"res://source/match/units/cavalry.tscn": "Cavalry",
}

@onready var _prod_label = find_child("ProductionLabel")


func _ready():
	await super()
	var toggle = find_child("ProductionToggle")
	if toggle != null:
		toggle.toggled.connect(_on_toggle_changed)
	_update_label("")


func _on_toggle_changed(scene_path: String):
	_update_label(scene_path)


func _update_label(scene_path: String):
	if _prod_label == null:
		return
	_prod_label.text = TYPE_NAMES.get(scene_path, "")
