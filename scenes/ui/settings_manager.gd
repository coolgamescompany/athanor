extends Node

signal fov_changed(new_fov: float)

const SAVE_PATH = "user://settings.cfg"

# Глобальные переменные для доступа из других скриптов (например, player.gd)
var mouse_sensitivity: float = 1.0
var mouse_inverted: bool = false
var show_fps_counter: bool = false


func _ready() -> void:
	load_game_settings()

func load_game_settings() -> void:
	if !FileAccess.file_exists(SAVE_PATH):
		_set_default_runtime_settings()
		return

	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		# --- ВИДЕО ---
		var mode_idx = config.get_value("video", "window_mode", 0)
		_apply_window_mode(mode_idx)
			
		var vsync = config.get_value("video", "vsync", true)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

		# --- ЗВУК ---
		_set_bus_vol("Master", config.get_value("audio", "master_volume", 0.7))
		_set_bus_vol("Music", config.get_value("audio", "music_volume", 0.7))
		_set_bus_vol("Sfx", config.get_value("audio", "sfx_volume", 0.7))

		# --- ОБЩИЕ (FPS) ---
		var fps_limit = config.get_value("general", "fps_limit", 0)
		Engine.max_fps = fps_limit

		# Читаем, включен ли счетчик
		show_fps_counter = config.get_value("general", "show_fps", false)

		# --- УПРАВЛЕНИЕ ---
		mouse_sensitivity = config.get_value("controls", "mouse_sensitivity", 0.1)
		mouse_inverted = config.get_value("controls", "mouse_inverted", false)
		
		# Загрузка клавиш
		if config.has_section("keybinds"):
			for action in config.get_section_keys("keybinds"):
				var key_scancode = config.get_value("keybinds", action)
				_apply_keybind(action, key_scancode)

		# --- ЯЗЫК ---
		TranslationServer.set_locale(config.get_value("general", "locale", "ru"))

func _set_default_runtime_settings():
	_set_bus_vol("Master", 0.7)
	_set_bus_vol("Music", 0.7)
	_set_bus_vol("Sfx", 0.7)
	Engine.max_fps = 0

func _set_bus_vol(bus_name: String, value: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
		AudioServer.set_bus_mute(bus_idx, value == 0)

func _apply_window_mode(index: int):
	match index:
		0: # Оконный
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1: # Полноэкранный
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2: # Полуоконный (Borderless Windowed)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

func _apply_keybind(action: String, scancode: int):
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
		var new_key = InputEventKey.new()
		new_key.physical_keycode = scancode
		InputMap.action_add_event(action, new_key)
