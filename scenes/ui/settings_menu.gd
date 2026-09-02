extends Control

const SAVE_PATH = "user://settings.cfg"
const ENV_PATH = "res://shaders/space_env.tres" # Путь к твоему файлу постобработки

var config = ConfigFile.new()
var is_loading: bool = true

# Для назначения клавиш
var key_waiting_for_action: String = ""
var key_waiting_button: Button = null

# --- УЗЛЫ UI ---
@onready var resolution_btn = %OptionButtonResolution
@onready var window_mode_btn = %OptionButtonMode
@onready var vsync_btn = %CheckButtonVsync
@onready var graphics_btn = %OptionButtonGraphics
@onready var fov_slider = %SliderFOV

@onready var master_slider = %SliderMaster
@onready var music_slider = %SliderMusic
@onready var sfx_slider = %SliderSfx

@onready var language_btn = %OptionButtonLanguage
@onready var fps_btn = %CheckButtonFPS
@onready var fps_limit_btn = %OptionButtonFPSLimit
@onready var reset_progress_btn = %ResetProgressButton
@onready var reset_settings_btn = %ResetSettingsButton

@onready var mouse_sens_slider = %SliderMouseSens
@onready var mouse_invert_btn = %CheckButtonMouseInvert
@onready var keybinds_grid = %KeybindsGrid

const RESOLUTIONS = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const LANGUAGES = ["ru", "en"]
const FPS_LIMITS = [0, 30, 60, 144, 240]

const CONFIGURABLE_ACTIONS = {
	"move_forward": "Вперед",
	"move_backward": "Назад",
	"move_left": "Влево",
	"move_right": "Вправо",
	"jump": "Прыжок",
	"interact": "Действие"
}

func _ready():
	is_loading = true
	_init_ui_elements()
	_create_keybind_menu()
	load_settings()
	_play_entrance_animation()
	is_loading = false

func _init_ui_elements():
	# Видео (Разрешение)
	resolution_btn.clear()
	for res in RESOLUTIONS: 
		resolution_btn.add_item(str(res.x) + " x " + str(res.y))
	resolution_btn.item_selected.connect(_on_resolution_selected)
	
	# Оконный режим
	window_mode_btn.clear()
	window_mode_btn.add_item("Оконный")
	window_mode_btn.add_item("Полноэкранный")
	window_mode_btn.add_item("Полуоконный")
	window_mode_btn.item_selected.connect(_on_window_mode_selected)
	
	# Вертикальная синхронизация
	vsync_btn.toggled.connect(_on_vsync_toggled)
	
	# Качество графики
	graphics_btn.clear()
	for q in ["Низкое", "Среднее", "Высокое", "Ультра"]:
		graphics_btn.add_item(q)
	graphics_btn.item_selected.connect(_on_graphics_selected)
	
	# Угол обзора (FOV)
	fov_slider.min_value = 60
	fov_slider.max_value = 120
	fov_slider.step = 1
	fov_slider.value_changed.connect(func(val):
		SettingsManager.fov_changed.emit(val)
		_auto_save_check()
	)
	
	# Звук
	for slider in [master_slider, music_slider, sfx_slider]:
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
	master_slider.value_changed.connect(_on_master_slider_value_changed)
	music_slider.value_changed.connect(_on_music_slider_value_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_value_changed)
	
	# Общие (Язык)
	language_btn.clear()
	language_btn.add_item("Русский")
	language_btn.add_item("English")
	language_btn.item_selected.connect(_on_language_selected)
	
	# Отображение FPS и Лимит FPS
	fps_btn.toggled.connect(_on_fps_toggled)
	
	fps_limit_btn.clear()
	for limit in FPS_LIMITS:
		fps_limit_btn.add_item("Без ограничений" if limit == 0 else str(limit) + " FPS")
	fps_limit_btn.item_selected.connect(_on_fps_limit_selected)
	
	# Кнопки сброса
	reset_progress_btn.pressed.connect(_on_reset_progress_pressed)
	reset_settings_btn.pressed.connect(_on_reset_settings_pressed)
	
	# Управление (Мышь)
	mouse_sens_slider.min_value = 0.01
	mouse_sens_slider.max_value = 1.0
	mouse_sens_slider.step = 0.01
	mouse_sens_slider.value_changed.connect(_on_mouse_sens_changed)
	mouse_invert_btn.toggled.connect(_on_mouse_invert_toggled)

func _create_keybind_menu():
	for child in keybinds_grid.get_children(): 
		child.queue_free()
		
	for action in CONFIGURABLE_ACTIONS:
		var label = Label.new()
		label.text = CONFIGURABLE_ACTIONS[action]
		keybinds_grid.add_child(label)
		
		var button = Button.new()
		button.text = _get_action_key_text(action)
		button.pressed.connect(_on_keybind_button_pressed.bind(action, button))
		keybinds_grid.add_child(button)

func _get_action_key_text(action: String) -> String:
	var events = InputMap.action_get_events(action)
	if events.size() > 0 and events[0] is InputEventKey:
		return OS.get_keycode_string(events[0].physical_keycode)
	return "Не назначено"

func _on_keybind_button_pressed(action: String, button: Button):
	if key_waiting_for_action != "": 
		return
	key_waiting_for_action = action
	key_waiting_button = button
	button.text = "... Нажмите клавишу ..."

func _input(event):
	if key_waiting_for_action != "" and event is InputEventKey and event.is_pressed():
		var scancode = event.physical_keycode
		SettingsManager._apply_keybind(key_waiting_for_action, scancode)
		
		key_waiting_button.text = OS.get_keycode_string(scancode)
		config.set_value("keybinds", key_waiting_for_action, scancode)
		config.save(SAVE_PATH)
		
		key_waiting_for_action = ""
		key_waiting_button = null
		get_viewport().set_input_as_handled()

func load_settings():
	if !FileAccess.file_exists(SAVE_PATH):
		_set_defaults()
		return
		
	if config.load(SAVE_PATH) != OK: 
		return
		
	resolution_btn.selected = config.get_value("video", "resolution_index", 2)
	_on_resolution_selected(resolution_btn.selected)
	
	window_mode_btn.selected = config.get_value("video", "window_mode", 0)
	_on_window_mode_selected(window_mode_btn.selected)
	
	vsync_btn.button_pressed = config.get_value("video", "vsync", true)
	
	# ИСПРАВЛЕНИЕ ТУТ: Сначала считываем сохраненный индекс из конфига, а потом активируем его график
	var saved_graphics = config.get_value("video", "graphics_quality", 2)
	graphics_btn.selected = saved_graphics
	_on_graphics_selected(saved_graphics)
	
	fov_slider.value = config.get_value("video", "fov", 75)
	SettingsManager.fov_changed.emit(fov_slider.value)
	
	master_slider.value = config.get_value("audio", "master_volume", 0.7)
	music_slider.value = config.get_value("audio", "music_volume", 0.7)
	sfx_slider.value = config.get_value("audio", "sfx_volume", 0.7)
	
	_on_master_slider_value_changed(master_slider.value)
	_on_music_slider_value_changed(music_slider.value)
	_on_sfx_slider_value_changed(sfx_slider.value)
	
	fps_btn.button_pressed = config.get_value("general", "show_fps", false)
	
	var limit_val = config.get_value("general", "fps_limit", 0)
	fps_limit_btn.selected = FPS_LIMITS.find(limit_val) if FPS_LIMITS.find(limit_val) != -1 else 0
	_on_fps_limit_selected(fps_limit_btn.selected)
	
	mouse_sens_slider.value = config.get_value("controls", "mouse_sensitivity", 20)
	_on_mouse_sens_changed(mouse_sens_slider.value)
	
	mouse_invert_btn.button_pressed = config.get_value("controls", "mouse_inverted", false)
	_on_mouse_invert_toggled(mouse_invert_btn.button_pressed)
	
	var current_lang = config.get_value("general", "locale", "ru")
	language_btn.selected = LANGUAGES.find(current_lang) if LANGUAGES.find(current_lang) != -1 else 0
	TranslationServer.set_locale(current_lang)
	
	_create_keybind_menu()


func _set_defaults():
	master_slider.value = 0.7
	music_slider.value = 0.7
	sfx_slider.value = 0.7
	fov_slider.value = 85 # Сделали дефолтный FOV приятным для 3D
	window_mode_btn.selected = 0
	vsync_btn.button_pressed = true
	fps_btn.button_pressed = false
	fps_limit_btn.selected = 0
	graphics_btn.selected = 2
	mouse_sens_slider.value = 0.5
	mouse_invert_btn.button_pressed = false
	
	_on_master_slider_value_changed(0.7)
	_on_music_slider_value_changed(0.7)
	_on_sfx_slider_value_changed(0.7)
	_on_mouse_sens_changed(0.5)
	_on_mouse_invert_toggled(false)
	_on_graphics_selected(2) # Сброс на Высокие
	
	SettingsManager.fov_changed.emit(85)

func save_settings():
	config.set_value("video", "resolution_index", resolution_btn.selected)
	config.set_value("video", "window_mode", window_mode_btn.selected)
	config.set_value("video", "vsync", vsync_btn.button_pressed)
	config.set_value("video", "graphics_quality", graphics_btn.selected)
	config.set_value("video", "fov", fov_slider.value)
	
	config.set_value("audio", "master_volume", master_slider.value)
	config.set_value("audio", "music_volume", music_slider.value)
	config.set_value("audio", "sfx_volume", sfx_slider.value)
	
	config.set_value("general", "show_fps", fps_btn.button_pressed)
	config.set_value("general", "fps_limit", FPS_LIMITS[fps_limit_btn.selected])
	config.set_value("general", "locale", LANGUAGES[language_btn.selected])
	
	config.set_value("controls", "mouse_sensitivity", mouse_sens_slider.value)
	config.set_value("controls", "mouse_inverted", mouse_invert_btn.button_pressed)
	config.save(SAVE_PATH)

func _auto_save_check():
	# Если мы сейчас загружаемся (is_loading == true), то СТРОГО запрещаем сохранение!
	if is_loading:
		return
	save_settings()

func _on_resolution_selected(index):
	DisplayServer.window_set_size(RESOLUTIONS[index])
	_auto_save_check()

func _on_window_mode_selected(index):
	SettingsManager._apply_window_mode(index)
	_auto_save_check()

func _on_vsync_toggled(toggled_on):
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if toggled_on else DisplayServer.VSYNC_DISABLED)
	_auto_save_check()

func _on_graphics_selected(index):
	var env = load(ENV_PATH) as Environment
	if env:
		match index:
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
				
	# Важно: вызываем сохранение только если мы НЕ в процессе загрузки меню
	if !is_loading:
		_auto_save_check()

				
func _on_master_slider_value_changed(value):
	SettingsManager._set_bus_vol("Master", value)
	
func _on_music_slider_value_changed(value):
	SettingsManager._set_bus_vol("Music", value)
	
func _on_sfx_slider_value_changed(value):
	SettingsManager._set_bus_vol("Sfx", value)
	
func _on_language_selected(index):
	TranslationServer.set_locale(LANGUAGES[index])
	_auto_save_check()

func _on_fps_toggled(toggled_on):
	SettingsManager.show_fps_counter = toggled_on
	_auto_save_check()
	
func _on_fps_limit_selected(index):
	Engine.max_fps = FPS_LIMITS[index]
	_auto_save_check()
	
func _on_mouse_sens_changed(value):
	SettingsManager.mouse_sensitivity = value
	_auto_save_check()
	
func _on_mouse_invert_toggled(toggled_on):
	SettingsManager.mouse_inverted = toggled_on
	_auto_save_check()

func _on_reset_progress_pressed():
	if FileAccess.file_exists("user://save_game.dat"):
		DirAccess.remove_absolute("user://save_game.dat")

func _on_reset_settings_pressed():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		get_tree().reload_current_scene()

func _play_entrance_animation():
	%MainPanel.modulate.a = 0.0
	%MainPanel.scale = Vector2(0.9, 0.9)
	%MainPanel.pivot_offset = %MainPanel.get_combined_minimum_size() / 2
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(%MainPanel, "modulate:a", 1.0, 0.3)
	tween.tween_property(%MainPanel, "scale", Vector2.ONE, 0.3)

func _on_back_button_pressed():
	queue_free()
