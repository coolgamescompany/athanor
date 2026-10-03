extends Node3D

@export var default_color: Color = Color.WHITE
@export var hover_color: Color = Color("ca55dfff")
@export var animate_time: float = 0.2

@onready var hover_sound: AudioStreamPlayer = %MenuHoverSound
@onready var click_sound: AudioStreamPlayer = %MenuClickSound


func _ready() -> void:
	SettingsManager.apply_saved_graphics()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hover_sound.bus = "Sfx"
	click_sound.bus = "Sfx"

	await get_tree().process_frame
	MusicManager.play_menu()

	var buttons: Array[Button] = [%PlayButton, %SettingsButton, %ExitButton]
	for btn in buttons:
		btn.focus_mode = Control.FOCUS_NONE
		btn.modulate = default_color
		if not btn.mouse_entered.is_connected(_on_btn_hover_start):
			btn.mouse_entered.connect(_on_btn_hover_start.bind(btn))
		if not btn.mouse_exited.is_connected(_on_btn_hover_end):
			btn.mouse_exited.connect(_on_btn_hover_end.bind(btn))

	var play_button: Button = %PlayButton
	play_button.modulate.a = 0.0
	play_button.text = "KEY_MENU_CONTINUE" if SaveManager.has_save() else "KEY_MENU_PLAY"
	await get_tree().process_frame
	var show_tween: Tween = create_tween()
	show_tween.tween_property(play_button, "modulate:a", 1.0, 0.1)


func _on_btn_hover_start(btn: Button) -> void:
	if hover_sound:
		hover_sound.pitch_scale = randf_range(0.95, 1.05)
		hover_sound.play()
	var tween: Tween = create_tween()
	tween.tween_property(btn, "modulate", hover_color, animate_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_btn_hover_end(btn: Button) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(btn, "modulate", default_color, animate_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_play_button_pressed() -> void:
	if click_sound:
		click_sound.play()
	if not SaveManager.has_save():
		StoryManager.reset_story()
	SceneLoader.change_scene_async("res://world.tscn")


func _on_settings_button_pressed() -> void:
	if click_sound:
		click_sound.play()
	if $MainMenu.get_node_or_null("SettingsMenu"):
		return
	var settings_instance: Node = preload("res://scenes/ui/settings_menu.tscn").instantiate()
	$MainMenu.add_child(settings_instance)


func _on_exit_button_pressed() -> void:
	if click_sound:
		click_sound.play()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()
