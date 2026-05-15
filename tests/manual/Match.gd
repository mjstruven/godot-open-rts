extends "res://source/match/Match.gd"

const EngineerScene = preload("res://source/match/units/engineer.tscn")

@export var allow_resources_deficit_spending = true


func _ready():
	find_child("MatchEndHandler").queue_free()
	FeatureFlags.allow_resources_deficit_spending = allow_resources_deficit_spending
	super()


func _spawn_player_units(player, spawn_transform):
	_setup_and_spawn_unit(EngineerScene.instantiate(), spawn_transform, player)
