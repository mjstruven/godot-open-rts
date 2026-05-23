const OWNED_PLAYER_CIRCLE_COLOR = Color.GREEN
const ADVERSARY_PLAYER_CIRCLE_COLOR = Color.RED
const RESOURCE_CIRCLE_COLOR = Color.YELLOW
const DEFAULT_CIRCLE_COLOR = Color.WHITE
const MAPS = {
	"res://source/match/maps/PlainAndSimple.tscn":
	{
		"name": "Plain & Simple",
		"players": 4,
		"size": Vector2i(50, 50),
	},
	"res://source/match/maps/BigArena.tscn":
	{
		"name": "Big Arena",
		"players": 8,
		"size": Vector2i(100, 100),
	},
	"res://source/match/maps/RoughMap1NotMirrored.tscn":
	{
		"name": "Rough Map 1 (Asymmetric)",
		"players": 2,
		"size": Vector2i(256, 256),
	},
	"res://source/match/maps/SiegeOfAshenmoor.tscn":
	{
		"name": "The Siege of Ashenmoor",
		"players": 2,
		"size": Vector2i(256, 256),
	},
	"res://source/match/maps/TheFertileCrescent.tscn":
	{
		"name": "The Fertile Crescent",
		"players": 2,
		"size": Vector2i(256, 256),
	},
	"res://source/match/maps/TestTerrainMap.tscn":
	{
		"name": "Terrain Test Map",
		"players": 2,
		"size": Vector2i(128, 128),
	},
}


class Navigation:
	enum Domain { AIR, TERRAIN }

	const DOMAIN_TO_GROUP_MAPPING = {
		Domain.AIR: "air_navigation_input",
		Domain.TERRAIN: "terrain_navigation_input",
	}


class Air:
	const Y = 1.5
	const PLANE = Plane(Vector3.UP, Y)

	class Navmesh:
		const CELL_SIZE = 0.4
		const CELL_HEIGHT = 0.4
		const MAX_AGENT_RADIUS = 0.8


class Terrain:
	const PLANE = Plane(Vector3.UP, 0)

	class Navmesh:
		const CELL_SIZE = 0.3
		const CELL_HEIGHT = 0.3
		const MAX_AGENT_RADIUS = 0.9  # max radius of movable units


class Resources:
	class Food:
		const COLOR = Color(0.2, 0.8, 0.2)

	class Wood:
		const COLOR = Color(0.5, 0.3, 0.1)

	class Stone:
		const COLOR = Color(0.6, 0.6, 0.6)

	class Gold:
		const COLOR = Color.YELLOW

	# kept for backward compatibility with sci-fi resource nodes
	class A:
		const COLOR = Color.BLUE
		const MATERIAL_PATH = "res://source/match/resources/materials/resource_a.material.tres"
		const COLLECTING_TIME_S = 1.0

	class B:
		const COLOR = Color.RED
		const MATERIAL_PATH = "res://source/match/resources/materials/resource_b.material.tres"
		const COLLECTING_TIME_S = 2.0


class Units:
	const FLAG_COMMANDER_LIMIT = 1
	const PRODUCTION_COSTS = {
		"res://source/match/units/infantry.tscn": {"food": 15},
		"res://source/match/units/archer.tscn": {"food": 10, "wood": 10},
		"res://source/match/units/cavalry.tscn": {"food": 25, "gold": 5},
		"res://source/match/units/engineer.tscn": {"food": 20, "wood": 10},
		"res://source/match/units/supply_train.tscn": {"food": 80, "gold": 40},
		"res://source/match/units/flag_commander/flag_commander.tscn": {"gold": 150},
		"res://source/match/units/mercenary.tscn": {"gold": 250},
		"res://source/match/units/battering_ram.tscn": {"wood": 100, "stone": 150},
		"res://source/match/units/siege_tower.tscn": {"wood": 150, "stone": 100, "gold": 50},
		"res://source/match/units/ballista.tscn": {"wood": 120, "stone": 80, "gold": 30},
		"res://source/match/units/trebuchet.tscn": {"wood": 150, "stone": 100, "gold": 50},
	}
	const PRODUCTION_TIMES = {
		"res://source/match/units/infantry.tscn": 6.0,
		"res://source/match/units/archer.tscn": 12.0,
		"res://source/match/units/cavalry.tscn": 12.0,
		"res://source/match/units/engineer.tscn": 10.0,
		"res://source/match/units/supply_train.tscn": 45.0,
		"res://source/match/units/flag_commander/flag_commander.tscn": 30.0,
		"res://source/match/units/mercenary.tscn": 10.0,
		"res://source/match/units/battering_ram.tscn": 40.0,
		"res://source/match/units/siege_tower.tscn": 50.0,
		"res://source/match/units/ballista.tscn": 45.0,
		"res://source/match/units/trebuchet.tscn": 60.0,
	}
	const PRODUCTION_QUEUE_LIMIT = 5
	const STRUCTURE_BLUEPRINTS = {
		"res://source/match/units/grain_mill.tscn":
		"res://source/match/units/structure-geometries/GrainMillGeometry.tscn",
		"res://source/match/units/lumber_mill.tscn":
		"res://source/match/units/structure-geometries/LumberMillGeometry.tscn",
		"res://source/match/units/stone_mill.tscn":
		"res://source/match/units/structure-geometries/StoneMillGeometry.tscn",
		"res://source/match/units/house.tscn":
		"res://source/match/units/structure-geometries/GrainMillGeometry.tscn",
		"res://source/match/units/manor.tscn":
		"res://source/match/units/structure-geometries/GrainMillGeometry.tscn",
		"res://source/match/units/academy.tscn":
		"res://source/match/units/structure-geometries/TownCenterGeometry.tscn",
		"res://source/match/units/capital.tscn":
		"res://source/match/units/structure-geometries/CapitalGeometry.tscn",
		"res://source/match/units/command_post.tscn":
		"res://source/match/units/structure-geometries/CommandPostGeometry.tscn",
		"res://source/match/units/siege_workshop.tscn":
		"res://source/match/units/structure-geometries/SiegeWorkshopGeometry.tscn",
	}
	const CONSTRUCTION_COSTS = {
		"res://source/match/units/grain_mill.tscn": {"wood": 50, "stone": 20},
		"res://source/match/units/lumber_mill.tscn": {"wood": 50, "stone": 20},
		"res://source/match/units/stone_mill.tscn": {"wood": 20, "stone": 50},
		"res://source/match/units/house.tscn": {"wood": 100, "stone": 50},
		"res://source/match/units/manor.tscn": {"stone": 100},
		"res://source/match/units/academy.tscn": {"wood": 300, "stone": 200},
		"res://source/match/units/capital.tscn": {"wood": 600, "stone": 400},
		"res://source/match/units/command_post.tscn": {"wood": 600, "stone": 400},
		"res://source/match/units/siege_workshop.tscn": {"wood": 400, "stone": 300},
	}
	const DEFAULT_PROPERTIES = {
		"res://source/match/units/infantry.tscn":
		{
			"sight_range": 7.0,
			"hp": 60,
			"hp_max": 60,
			"attack_damage": 20,
			"attack_interval": 2.0,
			"attack_range": 1.0,
			"attack_domains": [Navigation.Domain.TERRAIN],
		},
		"res://source/match/units/archer.tscn":
		{
			"sight_range": 12.0,
			"hp": 40,
			"hp_max": 40,
			"attack_damage": 6,
			"attack_interval": 4.0,
			"attack_range": 15.0,
			"attack_domains": [Navigation.Domain.TERRAIN],
		},
		"res://source/match/units/cavalry.tscn":
		{
			"sight_range": 8.0,
			"hp": 160,
			"hp_max": 160,
			"attack_damage": 40,
			"attack_interval": 2.0,
			"attack_range": 1.0,
			"attack_domains": [Navigation.Domain.TERRAIN],
		},
		"res://source/match/units/supply_wagon_auto.tscn":
		{
			"sight_range": 2.5,
			"hp": 80,
			"hp_max": 80,
		},
		"res://source/match/units/supply_train_wagon.tscn":
		{
			"sight_range": 2.5,
			"hp": 80,
			"hp_max": 80,
		},
		"res://source/match/units/supply_train.tscn":
		{
			"sight_range": 10.0,
			"hp": 500,
			"hp_max": 500,
		},
		"res://source/match/units/engineer.tscn":
		{
			"sight_range": 6.0,
			"hp": 80,
			"hp_max": 80,
		},
		"res://source/match/units/laborer.tscn":
		{
			"sight_range": 4.0,
			"hp": 12,
			"hp_max": 12,
		},
		"res://source/match/units/grain_mill.tscn": {"sight_range": 5.0, "hp": 200, "hp_max": 200},
		"res://source/match/units/lumber_mill.tscn": {"sight_range": 5.0, "hp": 200, "hp_max": 200},
		"res://source/match/units/stone_mill.tscn": {"sight_range": 5.0, "hp": 200, "hp_max": 200},
		"res://source/match/units/house.tscn": {"sight_range": 5.0, "hp": 800, "hp_max": 800},
		"res://source/match/units/manor.tscn": {"sight_range": 6.0, "hp": 1000, "hp_max": 1000},
		"res://source/match/units/academy.tscn": {"sight_range": 8.0, "hp": 4000, "hp_max": 4000},
		"res://source/match/units/capital.tscn": {"sight_range": 10.0, "hp": 8000, "hp_max": 8000},
		"res://source/match/units/command_post.tscn": {"sight_range": 10.0, "hp": 4000, "hp_max": 4000},
		"res://source/match/units/flag_commander/flag_commander.tscn":
		{
			"sight_range": 8.0,
			"hp": 32,
			"hp_max": 32,
			"attack_damage": 4,
			"attack_interval": 2.0,
			"attack_range": 1.0,
			"attack_domains": [Navigation.Domain.TERRAIN],
		},
		"res://source/match/units/mercenary.tscn":
		{
			"sight_range": 8.0,
			"hp": 180,
			"hp_max": 180,
			"attack_damage": 30,
			"attack_interval": 2.0,
			"attack_range": 1.2,
			"attack_domains": [Navigation.Domain.TERRAIN],
		},
		"res://source/match/units/civilian.tscn": {"sight_range": 2.0, "hp": 10, "hp_max": 10},
		"res://source/match/units/siege_workshop.tscn":
		{"sight_range": 8.0, "hp": 3000, "hp_max": 3000},
		"res://source/match/units/battering_ram.tscn":
		{
			"sight_range": 6.0,
			"hp": 400,
			"hp_max": 400,
			"attack_damage": 80,
			"attack_interval": 3.0,
			"attack_range": 1.2,
			"attack_domains": [Navigation.Domain.TERRAIN],
		},
		"res://source/match/units/siege_tower.tscn":
		{
			"sight_range": 6.0,
			"hp": 2000,
			"hp_max": 2000,
		},
		"res://source/match/units/ballista.tscn":
		{
			"sight_range": 12.0,
			"hp": 600,
			"hp_max": 600,
			"attack_damage": 35,
			"attack_interval": 5.0,
			"attack_range": 10.0,
			"attack_domains": [Navigation.Domain.TERRAIN],
		},
		"res://source/match/units/siege_engineer.tscn":
		{
			"sight_range": 4.0,
			"hp": 400,
			"hp_max": 400,
		},
		"res://source/match/units/trebuchet.tscn":
		{
			"sight_range": 22.0,
			"hp": 700,
			"hp_max": 700,
			"attack_damage": 80,
			"attack_interval": 10.0,
			"attack_range": 30.0,
			"attack_domains": [Navigation.Domain.TERRAIN],
		},
	}
	const SUPPLY_TRAIN_BUILD_LIMIT = 2
	# All upkeep values are per minute, applied once per 60-second economy tick.
	const UPKEEP = {
		"res://source/match/units/infantry.tscn": {"food": 4},
		"res://source/match/units/archer.tscn": {"food": 5, "gold": 1},
		"res://source/match/units/cavalry.tscn": {"food": 8, "gold": 4},
		"res://source/match/units/supply_train.tscn": {"food": 8, "gold": 6},
		"res://source/match/units/flag_commander/flag_commander.tscn": {"gold": 2},
		"res://source/match/units/mercenary.tscn": {"food": 12, "gold": 8},
		"res://source/match/units/siege_tower.tscn": {"wood": 5, "gold": 5},
		"res://source/match/units/ballista.tscn": {"wood": 3, "gold": 4},
		"res://source/match/units/siege_engineer.tscn": {"food": 4},
		# Future units — add entries here when the scenes exist:
		# "res://source/match/units/battering_ram.tscn": {"gold": 4},
		"res://source/match/units/trebuchet.tscn": {"wood": 4, "gold": 6},
	}
	# Income from constructed buildings, per minute, applied each 60-second tick.
	# Mill food/wood/stone income is handled separately via supply wagons (60/min each).
	const BUILDING_INCOME = {
		"res://source/match/units/capital.tscn": {"food": 60, "wood": 60, "stone": 60, "gold": 60},
		"res://source/match/units/command_post.tscn": {"food": 60, "wood": 60, "stone": 60, "gold": 60},
		"res://source/match/units/house.tscn": {"gold": 10},
		"res://source/match/units/manor.tscn": {"gold": 100},
		# Future buildings:
		# "res://source/match/units/tavern.tscn": {"gold": 5},
	}
	const CAPITAL_INFLUENCE_RADIUS = 20.0
	const POPULATION_PER_CAPITAL = 0
	const POPULATION_PER_HOUSE = 10
	const POPULATION_PER_MANOR = 25
	const POPULATION_CAP_MAX = 100
	const PROJECTILES = {}
	const ADHERENCE_MARGIN_M = 0.3  # TODO: try lowering while fixing a 'push' problem
	const NEW_RESOURCE_SEARCH_RADIUS_M = 30
	const MOVING_UNIT_RADIUS_MAX_M = 1.0
	const EMPTY_SPACE_RADIUS_SURROUNDING_STRUCTURE_M = MOVING_UNIT_RADIUS_MAX_M * 2.5
	const STRUCTURE_CONSTRUCTING_SPEED = 0.1  # progress [0.0..1.0] per second, 10s for full build


class VoiceNarrator:
	enum Events {
		MATCH_STARTED,
		MATCH_ABORTED,
		MATCH_FINISHED_WITH_VICTORY,
		MATCH_FINISHED_WITH_DEFEAT,
		BASE_UNDER_ATTACK,
		UNIT_UNDER_ATTACK,
		UNIT_LOST,
		UNIT_PRODUCTION_STARTED,
		UNIT_PRODUCTION_FINISHED,
		UNIT_CONSTRUCTION_FINISHED,
		UNIT_HELLO,
		UNIT_ACK_1,
		UNIT_ACK_2,
		NOT_ENOUGH_RESOURCES,
	}

	const EVENT_TO_ASSET_MAPPING = {
		Events.MATCH_STARTED:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/battle_control_online.ogg"),
		Events.MATCH_ABORTED:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/battle_control_offline.ogg"),
		Events.MATCH_FINISHED_WITH_VICTORY:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/you_are_victorious.ogg"),
		Events.MATCH_FINISHED_WITH_DEFEAT:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/you_have_lost.ogg"),
		Events.BASE_UNDER_ATTACK:
		preload(
			"res://assets/voice/english/ttsmaker-com-148-alayna-us/your_base_is_under_attack.ogg"
		),
		Events.UNIT_UNDER_ATTACK:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/unit_under_attack.ogg"),
		Events.UNIT_LOST:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/unit_lost.ogg"),
		Events.UNIT_PRODUCTION_STARTED:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/training.ogg"),
		Events.UNIT_PRODUCTION_FINISHED:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/unit_ready.ogg"),
		Events.UNIT_CONSTRUCTION_FINISHED:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/construction_complete.ogg"),
		Events.UNIT_HELLO:
		preload("res://assets/voice/english/ttsmaker-com-2704-jackson-us/sir.ogg"),
		Events.UNIT_ACK_1:
		preload("res://assets/voice/english/ttsmaker-com-2704-jackson-us/yes_sir.ogg"),
		Events.UNIT_ACK_2:
		preload("res://assets/voice/english/ttsmaker-com-2704-jackson-us/acknowledged.ogg"),
		Events.NOT_ENOUGH_RESOURCES:
		preload("res://assets/voice/english/ttsmaker-com-148-alayna-us/not_enough_resources.ogg"),
	}
