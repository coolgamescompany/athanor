extends Node

signal fov_changed(new_fov: float)

const SAVE_PATH: String = "user://settings.cfg"
const ENV_PATH: String = "res://shaders/space_env.tres"
const DEFAULT_FOV: float = 85.0
const DEFAULT_MOUSE_SENS: float = 0.5
const DEFAULT_LOCALE: String = "ru"
const DEFAULT_GRAPHICS: int = 2

var current_fov: float = DEFAULT_FOV
var mouse_sensitivity: float = DEFAULT_MOUSE_SENS
var mouse_inverted: bool = false
var show_fps_counter: bool = false
var show_tutorial: bool = true
var show_3d_messages: bool = false
var _cached_world_env: WorldEnvironment = null


func _ready() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_set_default_runtime_settings()
	else:
		load_game_settings()


func _apply_graphics_preset(preset_idx: int) -> void:
	var vp_rid: RID = get_viewport().get_viewport_rid()

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

	var env_template: Environment = load(ENV_PATH) as Environment
	if env_template == null:
		return
	# Дублируем ресурс, чтобы не пачкать .tres в редакторе
	var env: Environment = env_template.duplicate() as Environment
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

	_apply_environment_to_scene(env)


func _apply_environment_to_scene(env: Environment) -> void:
	# Кэшируем узел окружения: он не меняется между пресетами графики.
	if not is_instance_valid(_cached_world_env) or _cached_world_env.is_queued_for_deletion():
		var tree: SceneTree = get_tree()
		if tree == null or tree.current_scene == null:
			return
		_cached_world_env = tree.current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if _cached_world_env:
		_cached_world_env.environment = env


func load_game_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	_apply_window_mode(int(config.get_value("video", "window_mode", 0)))
	var vsync: bool = config.get_value("video", "vsync", true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

	_set_bus_vol("Master", float(config.get_value("audio", "master_volume", 0.7)))
	_set_bus_vol("Music", float(config.get_value("audio", "music_volume", 0.7)))
	_set_bus_vol("Sfx", float(config.get_value("audio", "sfx_volume", 0.7)))

	Engine.max_fps = int(config.get_value("general", "fps_limit", 0))
	show_fps_counter = bool(config.get_value("general", "show_fps", false))
	show_tutorial = bool(config.get_value("general", "show_tutorial", true))
	show_3d_messages = bool(config.get_value("general", "show_3d_messages", false))

	mouse_sensitivity = clampf(float(config.get_value("controls", "mouse_sensitivity", DEFAULT_MOUSE_SENS)), 0.01, 1.0)
	mouse_inverted = bool(config.get_value("controls", "mouse_inverted", false))

	if config.has_section("keybinds"):
		for action in config.get_section_keys("keybinds"):
			_apply_keybind(str(action), int(config.get_value("keybinds", action)))

	TranslationServer.set_locale(str(config.get_value("general", "locale", DEFAULT_LOCALE)))
	current_fov = float(config.get_value("video", "fov", DEFAULT_FOV))
	fov_changed.emit(current_fov)
	_apply_graphics_preset(int(config.get_value("video", "graphics_quality", DEFAULT_GRAPHICS)))


func _set_default_runtime_settings() -> void:
	show_tutorial = true
	show_fps_counter = false
	show_3d_messages = false
	mouse_sensitivity = DEFAULT_MOUSE_SENS
	mouse_inverted = false
	current_fov = DEFAULT_FOV

	var d_config := ConfigFile.new()
	d_config.set_value("video", "resolution_index", 0)
	d_config.set_value("video", "window_mode", 0)
	d_config.set_value("video", "vsync", true)
	d_config.set_value("video", "graphics_quality", DEFAULT_GRAPHICS)
	d_config.set_value("video", "fov", DEFAULT_FOV)
	d_config.set_value("general", "show_tutorial", true)
	d_config.set_value("audio", "master_volume", 0.7)
	d_config.set_value("audio", "music_volume", 0.7)
	d_config.set_value("audio", "sfx_volume", 0.7)
	d_config.set_value("general", "show_fps", false)
	d_config.set_value("general", "fps_limit", 0)
	d_config.set_value("general", "locale", DEFAULT_LOCALE)
	d_config.set_value("controls", "mouse_sensitivity", DEFAULT_MOUSE_SENS)
	d_config.set_value("controls", "mouse_inverted", false)
	d_config.save(SAVE_PATH)
	load_game_settings()


func _set_bus_vol(bus_name: String, value: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return
	var linear: float = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear) if linear > 0.0 else -80.0)
	AudioServer.set_bus_mute(bus_idx, linear <= 0.0)


func _apply_window_mode(index: int) -> void:
	match index:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)


func _apply_keybind(action: String, scancode: int) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	var new_key := InputEventKey.new()
	new_key.physical_keycode = scancode as Key
	InputMap.action_add_event(action, new_key)


func apply_saved_graphics() -> void:
	await get_tree().process_frame
	var config_file := ConfigFile.new()
	if config_file.load(SAVE_PATH) == OK:
		var graphics_preset: int = int(config_file.get_value("video", "graphics_quality", DEFAULT_GRAPHICS))
		_apply_graphics_preset.call_deferred(graphics_preset)
