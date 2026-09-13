extends Node

signal fov_changed(new_fov: float)

const SAVE_PATH = "user://settings.cfg"

var current_fov: float = 75.0 # Стандартное значение по умолчанию


# Глобальные переменные для доступа из других скриптов (например, player.gd)
var mouse_sensitivity: float = 1.0
var mouse_inverted: bool = false
var show_fps_counter: bool = false


func _ready() -> void:
	load_game_settings()
	

func _apply_graphics_preset(preset_idx: int) -> void:
	var vp_rid = get_viewport().get_viewport_rid()
	
	# --- 1. НАСТРОЙКА СИСТЕМНОГО СГЛАЖИВАНИЯ (ВИДЕОКАРТА) ---
	match preset_idx:
		0: # НИЗКИЕ
			RenderingServer.viewport_set_msaa_3d(vp_rid, RenderingServer.VIEWPORT_MSAA_DISABLED)
			RenderingServer.viewport_set_screen_space_aa(vp_rid, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		1: # СРЕДНИЕ
			RenderingServer.viewport_set_msaa_3d(vp_rid, RenderingServer.VIEWPORT_MSAA_2X)
			RenderingServer.viewport_set_screen_space_aa(vp_rid, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		2: # ВЫСОКИЕ
			RenderingServer.viewport_set_msaa_3d(vp_rid, RenderingServer.VIEWPORT_MSAA_4X)
			RenderingServer.viewport_set_screen_space_aa(vp_rid, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
		3: # УЛЬТРА
			RenderingServer.viewport_set_msaa_3d(vp_rid, RenderingServer.VIEWPORT_MSAA_8X)
			RenderingServer.viewport_set_screen_space_aa(vp_rid, RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)

	# --- 2. НАСТРОЙКА КИНЕМАТОГРАФИЧЕСКИХ ЭФФЕКТОВ (ТУМАН, СВЕЧЕНИЕ, ТЕНИ) ---
	# Загружаем точно такой же файл окружения, как и в твоем меню настроек!
	var env = load("res://shaders/space_env.tres") as Environment
	if env:
		match preset_idx:
			0: # НИЗКОЕ
				env.tonemap_mode = Environment.TONE_MAPPER_ACES
				env.glow_enabled = false
				env.ssao_enabled = false
				env.ssil_enabled = false
				env.volumetric_fog_enabled = false
			1: # СРЕДНЕЕ
				env.tonemap_mode = Environment.TONE_MAPPER_ACES
				env.glow_enabled = true
				env.glow_bloom = 0.15
				env.ssao_enabled = false
				env.ssil_enabled = false
				env.volumetric_fog_enabled = true
				env.volumetric_fog_density = 0.01
			2: # ВЫСОКОЕ
				env.tonemap_mode = Environment.TONE_MAPPER_ACES
				env.glow_enabled = true
				env.glow_bloom = 0.3
				env.ssao_enabled = true
				env.ssil_enabled = false
				env.volumetric_fog_enabled = true
				env.volumetric_fog_density = 0.01
			3: # УЛЬТРА
				env.tonemap_mode = Environment.TONE_MAPPER_ACES
				env.glow_enabled = true
				env.glow_bloom = 0.4
				env.ssao_enabled = true
				env.ssil_enabled = true
				env.volumetric_fog_enabled = true
				env.volumetric_fog_density = 0.02




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
		
		# --- ЧТЕНИЕ И ПРИМЕНЕНИЕ ГРАФИКИ И FOV ---
		# Читаем FOV (если его нет в файле, берем 75.0)
		current_fov = config.get_value("video", "fov", 75.0)
		# Рассылаем сигнал всем, кто слушает (например, игроку), что FOV загружен!
		fov_changed.emit(current_fov)

		# Читаем пресет графики (0 - Низкие, 1 - Средние, 2 - Высокие, 3 - Ультра)
		# Если в файле пусто, по умолчанию ставим 1 (Средние)
		var graphics_preset = config.get_value("video", "graphics_preset", 1)
		_apply_graphics_preset(graphics_preset)



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

# Универсальная функция, которую мы будем вызывать из других сцен
func apply_saved_graphics() -> void:
	# Даем 3D-миру один кадр прогрузиться
	await get_tree().process_frame
	
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		# Читаем именно тот ключ, в который сохраняет твое меню: "graphics_quality"
		var graphics_preset = config.get_value("video", "graphics_quality", 1)
		
		# Отложенно переписываем и видеокарту, и файл space_env.tres!
		_apply_graphics_preset.call_deferred(graphics_preset)
