extends Control

const MSG_DURATION = 8.0
const MAX_MESSAGES = 6

@onready var _match = find_parent("Match")

var _messages_container: VBoxContainer
var _chat_input: LineEdit


func _ready():
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_ui()


func _build_ui() -> void:
	_messages_container = VBoxContainer.new()
	_messages_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_messages_container.offset_bottom = -30.0
	_messages_container.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_messages_container)

	_chat_input = LineEdit.new()
	_chat_input.anchor_top = 1.0
	_chat_input.anchor_right = 1.0
	_chat_input.anchor_bottom = 1.0
	_chat_input.offset_top = -28.0
	_chat_input.placeholder_text = "Type a message — Enter to send, Esc to cancel"
	_chat_input.visible = false
	_chat_input.text_submitted.connect(_on_text_submitted)
	_chat_input.focus_exited.connect(_on_focus_exited)
	add_child(_chat_input)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		if not _chat_input.visible:
			_show_input()
			get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and _chat_input.visible:
		_hide_input()
		get_viewport().set_input_as_handled()


func _show_input() -> void:
	_chat_input.text = ""
	_chat_input.show()
	_chat_input.grab_focus()


func _hide_input() -> void:
	_chat_input.hide()
	_chat_input.release_focus()


func _on_text_submitted(text: String) -> void:
	_hide_input()
	var trimmed = text.strip_edges()
	if trimmed.is_empty():
		return
	_process_message(trimmed)


func _on_focus_exited() -> void:
	_hide_input()


func _process_message(text: String) -> void:
	if text.to_lower() == "reveal map":
		if _match != null and is_instance_valid(_match):
			_match.fog_of_war.reveal()
			var uv_handler = _match.find_child("UnitVisibilityHandler")
			if uv_handler != null:
				uv_handler.visible = false
		return
	_add_chat_label("[All] " + text)


func _add_chat_label(text: String) -> void:
	while _messages_container.get_child_count() >= MAX_MESSAGES:
		_messages_container.get_child(0).queue_free()

	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	_messages_container.add_child(label)

	get_tree().create_timer(MSG_DURATION).timeout.connect(func():
		if is_instance_valid(label):
			label.queue_free()
	)
