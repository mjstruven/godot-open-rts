extends PanelContainer

var player = null

@onready var _food_label = find_child("FoodLabel")
@onready var _wood_label = find_child("WoodLabel")
@onready var _stone_label = find_child("StoneLabel")
@onready var _gold_label = find_child("GoldLabel")
@onready var _deficit_label = find_child("DeficitLabel")


func setup(a_player):
	assert(player == null, "player cannot be null")
	player = a_player
	_on_player_changed()
	player.changed.connect(_on_player_changed)


func _on_player_changed():
	_food_label.text = str(player.food)
	_wood_label.text = str(player.wood)
	_stone_label.text = str(player.stone)
	_gold_label.text = str(player.gold)
	if _deficit_label != null:
		_deficit_label.visible = player.has_deficit
