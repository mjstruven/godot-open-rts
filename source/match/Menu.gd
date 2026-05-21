extends CanvasLayer

var _match_ended: bool = false


func _ready():
	hide()
	MatchSignals.match_finished_with_victory.connect(func(): _match_ended = true)
	MatchSignals.match_finished_with_defeat.connect(func(): _match_ended = true)


func _unhandled_input(event):
	if not event.is_action_pressed("toggle_match_menu"):
		return
	if visible:
		_toggle()
	elif not get_tree().paused or _match_ended:
		_toggle()


func _toggle():
	visible = not visible
	if not _match_ended:
		get_tree().paused = visible


func _on_resume_button_pressed():
	_toggle()


func _on_exit_button_pressed():
	MatchSignals.match_aborted.emit()
	await get_tree().create_timer(1.74).timeout  # Give voice narrator some time to finish.
	get_tree().paused = false
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
