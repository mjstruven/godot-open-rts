extends Node3D

signal changed

@export var food = 0:
	set(value):
		food = value
		emit_changed()
@export var wood = 0:
	set(value):
		wood = value
		emit_changed()
@export var stone = 0:
	set(value):
		stone = value
		emit_changed()
@export var gold = 0:
	set(value):
		gold = value
		emit_changed()
@export var color = Color.WHITE

var has_deficit = false
var _color_material = null


func add_resources(resources):
	for resource in resources:
		set(resource, get(resource) + resources[resource])


func has_resources(resources):
	if FeatureFlags.allow_resources_deficit_spending:
		return true
	for resource in resources:
		if get(resource) < resources[resource]:
			return false
	return true


func subtract_resources(resources):
	for resource in resources:
		set(resource, get(resource) - resources[resource])


func get_color_material():
	if _color_material == null:
		_color_material = StandardMaterial3D.new()
		_color_material.vertex_color_use_as_albedo = true
		_color_material.albedo_color = color
		_color_material.metallic = 1
	return _color_material


func emit_changed():
	changed.emit()
