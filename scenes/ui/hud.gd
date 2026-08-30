extends Control

@onready var label = %FPSLabel

func _ready() -> void:
	# Подписываемся на глобальный синглтон настроек
	SettingsManager.fov_changed.connect(func(val): pass) # Просто пример

func _process(_delta: float) -> void:
	# Проверяем, разрешил ли игрок показывать FPS в файле конфигурации
	if Engine.get_frames_per_second() > 0 and SettingsManager.show_fps_counter:
		visible = true
		label.text = "FPS: " + str(Engine.get_frames_per_second())
	else:
		visible = false
