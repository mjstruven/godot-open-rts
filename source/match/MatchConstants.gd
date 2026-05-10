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
	const PRODUCTION_COSTS = {
		"res://source/match/units/Worker.tscn":
		{
			"food": 2,
			"gold": 0,
		},
		"res://source/match/units/Helicopter.tscn":
		{
			"food": 1,
			"gold": 3,
		},
		"res://source/match/units/Drone.tscn":
		{
			"food": 2,
			"gold": 0,
		},
		"res://source/match/units/Tank.tscn":
		{
			"food": 3,
			"gold": 1,
		},
		"res://source/match/units/infantry.tscn":
		{
			"food": 15,
		},
		"res://source/match/units/archer.tscn":
		{
			"food": 10,
			"wood": 10,
		},
		"res://source/match/units/cavalry.tscn":
		{
			"food": 25,
			"gold": 5,
		},
	}
	const PRODUCTION_TIMES = {
		"res://source/match/units/Worker.tscn": 3.0,
		"res://source/match/units/Helicopter.tscn": 6.0,
		"res://source/match/units/Drone.tscn": 3.0,
		"res://source/match/units/Tank.tscn": 6.0,
		"res://source/match/units/infantry.tscn": 6.0,
		"res://source/match/units/archer.tscn": 12.0,
		"res://source/match/units/cavalry.tscn": 12.0,
	}
	const PRODUCTION_QUEUE_LIMIT = 5
	const STRUCTURE_BLUEPRINTS = {
		"res://source/match/units/CommandCenter.tscn":
		"res://source/match/units/structure-geometries/CommandCenter.tscn",
		"res://source/match/units/VehicleFactory.tscn":
		"res://source/match/units/structure-geometries/VehicleFactory.tscn",
		"res://source/match/units/AircraftFactory.tscn":
		"res://source/match/units/structure-geometries/AircraftFactory.tscn",
		"res://source/match/units/AntiGroundTurret.tscn":
		"res://source/match/units/structure-geometries/AntiGroundTurret.tscn",
		"res://source/match/units/AntiAirTurret.tscn":
		"res://source/match/units/structure-geometries/AntiAirTurret.tscn",
		"res://source/match/units/grain_mill.tscn":
		"res://source/match/units/structure-geometries/GrainMillGeometry.tscn",
		"res://source/match/units/lumber_mill.tscn":
		"res://source/match/units/structure-geometries/LumberMillGeometry.tscn",
		"res://source/match/units/stone_mill.tscn":
		"res://source/match/units/structure-geometries/StoneMillGeometry.tscn",
		"res://source/match/units/town_center.tscn":
		"res://source/match/units/structure-geometries/TownCenterGeometry.tscn",
		"res://source/match/units/capital.tscn":
		"res://source/match/units/structure-geometries/CapitalGeometry.tscn",
	}
	const CONSTRUCTION_COSTS = {
		"res://source/match/units/CommandCenter.tscn":
		{
			"food": 0,
			"gold": 8,
		},
		"res://source/match/units/VehicleFactory.tscn":
		{
			"food": 0,
			"gold": 6,
		},
		"res://source/match/units/AircraftFactory.tscn":
		{
			"food": 0,
			"gold": 4,
		},
		"res://source/match/units/AntiGroundTurret.tscn":
		{
			"food": 0,
			"gold": 2,
		},
		"res://source/match/units/AntiAirTurret.tscn":
		{
			"food": 0,
			"gold": 2,
		},
		"res://source/match/units/grain_mill.tscn":
		{
			"wood": 50,
			"stone": 20,
		},
		"res://source/match/units/lumber_mill.tscn":
		{
			"wood": 50,
			"stone": 20,
		},
		"res://source/match/units/stone_mill.tscn":
		{
			"wood": 20,
			"stone": 50,
		},
		"res://source/match/units/town_center.tscn":
		{
			"wood": 300,
			"stone": 200,
		},
		"res://source/match/units/capital.tscn":
		{
			"wood": 600,
			"stone": 400,
		},
	}
	const DEFAULT_PROPERTIES = {
		"res://source/match/units/infantry.tscn":
		{
			"sight_range": 7.0,
			"hp": 6,
			"hp_max": 6,
			"attack_damage": 2,
			"attack_interval": 2.0,
			"attack_range": 1.0,
			"attack_domains": [Navigation.Domain.TERRAIN],
		},
		"res://source/match/units/archer.tscn":
		{
			"sight_range": 12.0,
			"hp": 4,
			"hp_max": 4,
			"attack_damage": 6,
			"attack_interval": 6.0,
			"attack_range": 10.0,
			"attack_domains": [Navigation.Domain.TERRAIN],
		},
		"res://source/match/units/cavalry.tscn":
		{
			"sight_range": 8.0,
			"hp": 16,
			"hp_max": 16,
			"attack_damage": 4,
			"attack_interval": 2.0,
			"attack_range": 1.0,
			"attack_domains": [Navigation.Domain.TERRAIN],
		},
		"res://source/match/units/Drone.tscn":
		{
			"sight_range": 10.0,
			"hp": 6,
			"hp_max": 6,
		},
		"res://source/match/units/Worker.tscn":
		{
			"sight_range": 5.0,
			"hp": 6,
			"hp_max": 6,
			"resources_max": 2,
		},
		"res://source/match/units/Helicopter.tscn":
		{
			"sight_range": 8.0,
			"hp": 10,
			"hp_max": 10,
			"attack_damage": 1,
			"attack_interval": 1.0,
			"attack_range": 5.0,
			"attack_domains": [Navigation.Domain.TERRAIN, Navigation.Domain.AIR],
		},
		"res://source/match/units/Tank.tscn":
		{
			"sight_range": 8.0,
			"hp": 10,
			"hp_max": 10,
			"attack_damage": 2,
			"attack_interval": 0.75,
			"attack_range": 5.0,
			"attack_domains": [Navigation.Domain.TERRAIN],
		},
		"res://source/match/units/CommandCenter.tscn":
		{
			"sight_range": 10.0,
			"hp": 20,
			"hp_max": 20,
		},
		"res://source/match/units/VehicleFactory.tscn":
		{
			"sight_range": 8.0,
			"hp": 16,
			"hp_max": 16,
		},
		"res://source/match/units/AircraftFactory.tscn":
		{
			"sight_range": 8.0,
			"hp": 16,
			"hp_max": 16,
		},
		"res://source/match/units/AntiGroundTurret.tscn":
		{
			"sight_range": 8.0,
			"hp": 8,
			"hp_max": 8,
			"attack_damage": 2,
			"attack_interval": 1.0,
			"attack_range": 8.0,
			"attack_domains": [Navigation.Domain.TERRAIN],
		},
		"res://source/match/units/AntiAirTurret.tscn":
		{
			"sight_range": 8.0,
			"hp": 8,
			"hp_max": 8,
			"attack_damage": 2,
			"attack_interval": 0.75,
			"attack_range": 8.0,
			"attack_domains": [Navigation.Domain.AIR],
		},
		"res://source/match/units/grain_mill.tscn":
		{
			"sight_range": 5.0,
			"hp": 20,
			"hp_max": 20,
		},
		"res://source/match/units/lumber_mill.tscn":
		{
			"sight_range": 5.0,
			"hp": 20,
			"hp_max": 20,
		},
		"res://source/match/units/stone_mill.tscn":
		{
			"sight_range": 5.0,
			"hp": 20,
			"hp_max": 20,
		},
		"res://source/match/units/supply_wagon_auto.tscn":
		{
			"sight_range": 5.0,
			"hp": 8,
			"hp_max": 8,
		},
		"res://source/match/units/engineer.tscn":
		{
			"sight_range": 6.0,
			"hp": 8,
			"hp_max": 8,
		},
		"res://source/match/units/town_center.tscn":
		{
			"sight_range": 8.0,
			"hp": 400,
			"hp_max": 400,
		},
		"res://source/match/units/capital.tscn":
		{
			"sight_range": 10.0,
			"hp": 800,
			"hp_max": 800,
		},
	}
	const UPKEEP = {
		"res://source/match/units/infantry.tscn": {"food": 1},
		"res://source/match/units/archer.tscn": {"food": 1},
		"res://source/match/units/cavalry.tscn": {"food": 2},
	}
	const MILL_OUTPUT = {
		"res://source/match/units/grain_mill.tscn": {"food": 20},
		"res://source/match/units/lumber_mill.tscn": {"wood": 15},
		"res://source/match/units/stone_mill.tscn": {"stone": 10},
	}
	const PROJECTILES = {
		"res://source/match/units/Helicopter.tscn":
		"res://source/match/units/projectiles/Rocket.tscn",
		"res://source/match/units/Tank.tscn":
		"res://source/match/units/projectiles/CannonShell.tscn",
		"res://source/match/units/AntiGroundTurret.tscn":
		"res://source/match/units/projectiles/CannonShell.tscn",
		"res://source/match/units/AntiAirTurret.tscn":
		"res://source/match/units/projectiles/Rocket.tscn"
	}
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
