extends Node

enum Category { COMBAT, ECONOMY, AI, STARTUP }


func debug(category: int, message: String, data: Dictionary = {}):
	print("[DEBUG][%s] %s %s" % [Category.keys()[category], message, str(data)])


func info(category: int, message: String, data: Dictionary = {}):
	print("[INFO][%s] %s %s" % [Category.keys()[category], message, str(data)])


func balance(event_name: String, data: Dictionary = {}):
	print("[BALANCE] %s %s" % [event_name, str(data)])


func get_match_time() -> float:
	return Time.get_ticks_msec() / 1000.0
