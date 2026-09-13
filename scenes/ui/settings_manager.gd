extends Node

signal fov_changed(new_fov: float)

const SAVE_PATH = "user://settings.cfg"

var current_fov: float = 75.0 

# Глобальные переменные для доступа из других скриптов
var mouse_sensitivity: float = 0.5
var mouse_inverted: bool = false
var show_fps_counter: bool = false
var show_tutorial: bool = true # Изначально TRUE!

func _ready() -> void:
	# Если файла нет — принудительно создаем дефолтный конфиг на диске
	if !FileAccess.file_exists(SAVE_PATH):
		_set_default_runtime_settings()
	else:
		load_game_settings()

func _apply_graphics_preset(preset_idx: int) -> void:
	var vp_rid = get_viewport().get_viewport_rid()
	
	match preset_idx:
		0: 
			RenderingServer.viewport_set_msaa_3d(vp_rid, RenderingServer.VIEWPORT_MSAA_DISABLED)
			RenderingServer.viewport_set_screen_space_aa(vp_rid, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		1: 
			RenderingServer.viewport_set_msaa_3d(vp_rid, RenderingServer.VIEWPORT_MSAA_2X)
			RenderingServer.viewport_set_screen_space_aa(vp_rid, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		2: 
			RenderingServer.viewport_set_msaa_3d(vp_rid, RenderingServer.VIEWPORT_MSAA_4X)
			RenderingServer.viewport_set_screen_space_aa(vp_rid, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
		3: 
			RenderingServer.viewport_set_msaa_3d(vp_rid, RenderingServer.VIEWPORT_MSAA_8X)
			RenderingServer.viewport_set_screen_space_aa(vp_rid, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)

	var env = load("res://shaders/space_env.tres") as Environment
	if env:
		match preset_idx:
			0:
				env.tonemap_mode = Environment.TONE_MAPPER_ACES
				env.glow_enabled = false
				env.ssao_enabled = false
				env.ssil_enabled = false
				env.volumetric_fog_enabled = false
			1:
				env.tonemap_mode = Environment.TONE_MAPPER_ACES
				env.glow_enabled = true
				env.glow_bloom = 0.15
				env.ssao_enabled = false
				env.ssil_enabled = false
				env.volumetric_fog_enabled = true
				env.volumetric_fog_density = 0.01
			2:
				env.tonemap_mode = Environment.TONE_MAPPER_ACES
				env.glow_enabled = true
				env.glow_bloom = 0.3
				env.ssao_enabled = true
				env.ssil_enabled = false
				env.volumetric_fog_enabled = true
				env.volumetric_fog_density = 0.01
			3:
				env.tonemap_mode = Environment.TONE_MAPPER_ACES
				env.glow_enabled = true
				env.glow_bloom = 0.4
				env.ssao_enabled = true
				env.ssil_enabled = true
				env.volumetric_fog_enabled = true
				env.volumetric_fog_density = 0.02

func load_game_settings() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		var mode_idx = config.get_value("video", "window_mode", 0)
		_apply_window_mode(mode_idx)
			
		var vsync = config.get_value("video", "vsync", true)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

		_set_bus_vol("Master", config.get_value("audio", "master_volume", 0.7))
		_set_bus_vol("Music", config.get_value("audio", "music_volume", 0.7))
		_set_bus_vol("Sfx", config.get_value("audio", "sfx_volume", 0.7))

		Engine.max_fps = config.get_value("general", "fps_limit", 0)
		show_fps_counter = config.get_value("general", "show_fps", false)
		
		# Читаем обучение. Если в файле пусто, по умолчанию ставим TRUE
		show_tutorial = config.get_value("general", "show_tutorial", true) # Дефолт TRUE


		mouse_sensitivity = config.get_value("controls", "mouse_sensitivity", 0.5)
		mouse_inverted = config.get_value("controls", "mouse_inverted", false)
		
		if config.has_section("keybinds"):
			for action in config.get_section_keys("keybinds"):
				_apply_keybind(action, config.get_value("keybinds", action))

		TranslationServer.set_locale(config.get_value("general", "locale", "ru"))
		
		current_fov = config.get_value("video", "fov", 85.0)
		fov_changed.emit(current_fov)

		var graphics_preset = config.get_value("video", "graphics_quality", 1)
		_apply_graphics_preset(graphics_preset)

# ГЕНЕРАЦИЯ ДЕФОЛТНОГО ФАЙЛА НА ДИСКЕ
# ГЕНЕРАЦИЯ ДЕФОЛТНОГО ФАЙЛА НА ДИСКЕ
func _set_default_runtime_settings():
	show_tutorial = true # Жестко ВКЛЮЧЕНО при первом старте!
	show_fps_counter = false
	mouse_sensitivity = 0.5
	mouse_inverted = false
	current_fov = 85.0
	
	var d_config = ConfigFile.new()
	d_config.set_value("video", "resolution_index", 2)
	d_config.set_value("video", "window_mode", 0)
	d_config.set_value("video", "vsync", true)
	d_config.set_value("video", "graphics_quality", 1)
	d_config.set_value("video", "fov", 85.0)
	
	# ИСПРАВЛЕНО ТУТ: Записываем в дефолтный файл TRUE
	d_config.set_value("general", "show_tutorial", true)
	
	d_config.set_value("audio", "master_volume", 0.7)
	d_config.set_value("audio", "music_volume", 0.7)
	d_config.set_value("audio", "sfx_volume", 0.7)
	d_config.set_value("general", "show_fps", false)
	d_config.set_value("general", "fps_limit", 0)
	d_config.set_value("general", "locale", "ru")
	d_config.set_value("controls", "mouse_sensitivity", 0.5)
	d_config.set_value("controls", "mouse_inverted", false)
	d_config.save(SAVE_PATH) 
	
	load_game_settings()


func _set_bus_vol(bus_name: String, value: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))
		AudioServer.set_bus_mute(bus_idx, value == 0)

func _apply_window_mode(index: int):
	match index:
		0: 
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1: 
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2: 
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

func _apply_keybind(action: String, scancode: int):
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
		var new_key = InputEventKey.new()
		new_key.physical_keycode = scancode
		InputMap.action_add_event(action, new_key)

func apply_saved_graphics() -> void:
	await get_tree().process_frame
	var config_file = ConfigFile.new()
	if config_file.load(SAVE_PATH) == OK:
		var graphics_preset = config_file.get_value("video", "graphics_quality", 1)
		_apply_graphics_preset.call_deferred(graphics_preset)
