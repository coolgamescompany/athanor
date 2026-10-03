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
@onready var show_tutorial = %CheckButtonTutorial

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
@onready var apply_btn: Button = %SaveButton

const RESOLUTIONS = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const LANGUAGES = ["ru", "en"]
const FPS_LIMITS = [0, 30, 60, 144, 240]

const CONFIGURABLE_ACTIONS = {
	"move_forward": "Вперед",
	"move_backward": "Назад",
	"move_left": "Влево",
	"move_right": "Вправо",
	"jump": "Прыжок",
	"interact": "Действие",
	"crouch": "Присед",
	"sprint": "Бег"
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
	window_mode_btn.add_item("KEY_SETTINGS_WINDOW_MODE_WINDOW")
	window_mode_btn.add_item("KEY_SETTINGS_WINDOW_MODE_FULL")
	window_mode_btn.add_item("KEY_SETTINGS_WINDOW_MODE_HALF")
	window_mode_btn.item_selected.connect(_on_window_mode_selected)
	
	# Вертикальная синхронизация
	vsync_btn.toggled.connect(_on_vsync_toggled)
	
	# Качество графики
	graphics_btn.clear()
	for q in ["KEY_SETTINGS_QUALITY_LOW", "KEY_SETTINGS_QUALITY_MEDIUM", "KEY_SETTINGS_QUALITY_HIGH", "KEY_SETTINGS_QUALITY_ULTRA"]:
		graphics_btn.add_item(q)
	graphics_btn.item_selected.connect(_on_graphics_selected)
	
	# Угол обзора (FOV)
	fov_slider.min_value = 60
	fov_slider.max_value = 120
	fov_slider.step = 1
	fov_slider.value_changed.connect(func(val: float) -> void:
		SettingsManager.current_fov = val
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
		fps_limit_btn.add_item("KEY_BUTTON_WITHOUT_LIMIT" if limit == 0 else str(limit) + " FPS")
	fps_limit_btn.item_selected.connect(_on_fps_limit_selected)
	
	# Кнопки сброса
	if not reset_progress_btn.pressed.is_connected(_on_reset_progress_pressed):
		reset_progress_btn.pressed.connect(_on_reset_progress_pressed)
	reset_settings_btn.pressed.connect(_on_reset_settings_pressed)
	if apply_btn and not apply_btn.pressed.is_connected(save_settings):
		apply_btn.pressed.connect(save_settings)
	
	# Переключатель: 3D-текст vs UI-текст (добавляем в Controls tab)
	_add_ui_messages_toggle()
	
	# Управление (Мышь)
	mouse_sens_slider.min_value = 0.01
	mouse_sens_slider.max_value = 1.0
	mouse_sens_slider.step = 0.01
	mouse_sens_slider.value_changed.connect(_on_mouse_sens_changed)
	mouse_invert_btn.toggled.connect(_on_mouse_invert_toggled)
	
	show_tutorial.toggled.connect(_on_tutorial_toggled)
	
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
	
	# Имя твоей кнопки обучения в UI (поменяй на актуальное, если назвал иначе)
	show_tutorial.button_pressed = config.get_value("general", "show_tutorial", true)

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
	
	mouse_sens_slider.value = clampf(float(config.get_value("controls", "mouse_sensitivity", 0.5)), 0.01, 1.0)
	_on_mouse_sens_changed(mouse_sens_slider.value)
	
	mouse_invert_btn.button_pressed = config.get_value("controls", "mouse_inverted", false)
	_on_mouse_invert_toggled(mouse_invert_btn.button_pressed)
	
	var current_lang = config.get_value("general", "locale", "ru")
	language_btn.selected = LANGUAGES.find(current_lang) if LANGUAGES.find(current_lang) != -1 else 0
	TranslationServer.set_locale(current_lang)
	
	_create_keybind_menu()
	
	if _ui_messages_check:
		_ui_messages_check.button_pressed = SettingsManager.show_3d_messages


func _set_defaults():
	master_slider.value = 0.7
	music_slider.value = 0.7
	sfx_slider.value = 0.7
	show_tutorial.button_pressed = true
	SettingsManager.show_tutorial = true
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
	if _ui_messages_check:
		_ui_messages_check.button_pressed = false

func save_settings():
	config.set_value("video", "resolution_index", resolution_btn.selected)
	config.set_value("video", "window_mode", window_mode_btn.selected)
	config.set_value("video", "vsync", vsync_btn.button_pressed)
	config.set_value("video", "graphics_quality", graphics_btn.selected)
	config.set_value("video", "fov", fov_slider.value)
	
	# ИСПРАВЛЕНО ТУТ: Сохраняем реальное состояние кнопки из UI на диск!
	config.set_value("general", "show_tutorial", show_tutorial.button_pressed)
	
	config.set_value("audio", "master_volume", master_slider.value)
	config.set_value("audio", "music_volume", music_slider.value)
	config.set_value("audio", "sfx_volume", sfx_slider.value)
	
	config.set_value("general", "show_fps", fps_btn.button_pressed)
	config.set_value("general", "fps_limit", FPS_LIMITS[fps_limit_btn.selected])
	config.set_value("general", "locale", LANGUAGES[language_btn.selected])
	
	config.set_value("controls", "mouse_sensitivity", mouse_sens_slider.value)
	config.set_value("controls", "mouse_inverted", mouse_invert_btn.button_pressed)
	if _ui_messages_check:
		config.set_value("general", "show_3d_messages", _ui_messages_check.button_pressed)
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
	SettingsManager._apply_graphics_preset(index)
	if not is_loading:
		_auto_save_check()

				
func _on_master_slider_value_changed(value):
	SettingsManager._set_bus_vol("Master", value)
	_auto_save_check()

func _on_music_slider_value_changed(value):
	SettingsManager._set_bus_vol("Music", value)
	_auto_save_check()

func _on_sfx_slider_value_changed(value):
	SettingsManager._set_bus_vol("Sfx", value)
	_auto_save_check()
	
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
	SettingsManager.mouse_sensitivity = clampf(float(value), 0.01, 1.0)
	_auto_save_check()
	
func _on_mouse_invert_toggled(toggled_on):
	SettingsManager.mouse_inverted = toggled_on
	_auto_save_check()

func _on_reset_progress_button_pressed() -> void:
	_on_reset_progress_pressed()


func _on_reset_progress_pressed() -> void:
	SaveManager.clear_save()
	get_tree().paused = false
	SceneLoader.change_scene_async("res://scenes/ui/main_menu.tscn")


func _on_reset_settings_pressed():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		SceneLoader.reload_current_scene()

func _play_entrance_animation():
	%MainPanel.modulate.a = 0.0
	%MainPanel.scale = Vector2(0.9, 0.9)
	%MainPanel.pivot_offset = %MainPanel.get_combined_minimum_size() / 2
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(%MainPanel, "modulate:a", 1.0, 0.3)
	tween.tween_property(%MainPanel, "scale", Vector2.ONE, 0.3)


func _on_back_button_pressed():
	# Принудительно сохраняем всё на диск в момент, когда игрок нажимает "Назад"
	save_settings()
	queue_free()
	
func _on_tutorial_toggled(toggled_on: bool) -> void:
	# Напрямую переключаем флаг в синглтоне
	SettingsManager.show_tutorial = toggled_on
	_auto_save_check()


# ─── Настройка UI-текста вместо 3D ────────────────────────────────────────────

var _ui_messages_check: CheckButton = null

func _add_ui_messages_toggle() -> void:
	# Добавляем строку в Controls tab (GridContainer с 2 колонками)
	var main_grid: GridContainer = keybinds_grid.get_parent().get_parent() as GridContainer
	if main_grid == null:
		return
	var label: Label = Label.new()
	label.text = "KEY_SETTINGS_UI_MESSAGES"
	label.unique_name_in_owner = false
	main_grid.add_child(label)
	_ui_messages_check = CheckButton.new()
	_ui_messages_check.toggled.connect(_on_ui_messages_toggled)
	main_grid.add_child(_ui_messages_check)

func _on_ui_messages_toggled(toggled_on: bool) -> void:
	SettingsManager.show_3d_messages = toggled_on
	_auto_save_check()

# ─── Улучшенное переназначение клавиш ──────────────────────────────────────────

func _input(event):
	if key_waiting_for_action != "" and event.is_action_pressed("ui_cancel"):
		# Escape — отмена назначения
		key_waiting_button.text = _get_action_key_text(key_waiting_for_action)
		_abort_keybinding()
		get_viewport().set_input_as_handled()
		return
	if key_waiting_for_action != "" and event is InputEventKey and not event.echo and event.is_pressed():
		var scancode: int = event.physical_keycode
		# Проверяем дубликат — эту клавишу уже использует другое действие?
		_remove_duplicate_bind(scancode, key_waiting_for_action)
		
		SettingsManager._apply_keybind(key_waiting_for_action, scancode)
		key_waiting_button.text = OS.get_keycode_string(scancode)
		config.set_value("keybinds", key_waiting_for_action, scancode)
		config.save(SAVE_PATH)
		key_waiting_for_action = ""
		key_waiting_button = null
		get_viewport().set_input_as_handled()

func _abort_keybinding() -> void:
	key_waiting_for_action = ""
	key_waiting_button = null

func _remove_duplicate_bind(scancode: int, except_action: String) -> void:
	for action in CONFIGURABLE_ACTIONS:
		if action == except_action:
			continue
		var events: Array = InputMap.action_get_events(action)
		for ev in events:
			if ev is InputEventKey and ev.physical_keycode == scancode:
				InputMap.action_erase_event(action, ev)
				config.set_value("keybinds", action, -1)
				break
	# Обновляем текст кнопок в UI, если клавишу отвязали
	_create_keybind_menu()


func _on_keybind_button_pressed(action: String, button: Button):
	if key_waiting_for_action != "":
		_cancel_current_keybinding()
	key_waiting_for_action = action
	key_waiting_button = button
	button.text = "... Нажмите клавишу ..."

func _cancel_current_keybinding() -> void:
	if key_waiting_button:
		key_waiting_button.text = _get_action_key_text(key_waiting_for_action)
	key_waiting_for_action = ""
	key_waiting_button = null

func _get_action_key_text(action: String) -> String:
	var events: Array = InputMap.action_get_events(action)
	if events.size() > 0 and events[0] is InputEventKey:
		return OS.get_keycode_string(events[0].physical_keycode)
	return "—"
