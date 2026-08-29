extends Button

@export var default_color: Color = Color.WHITE
@export var hover_color: Color = Color("ce34e4ff") # Неоново-фиолетовый
@export var animate_time: float = 0.2

func _ready() -> void:
	# Настраиваем очистку фокуса, чтобы кнопка не «залипала» после клика
	focus_mode = FocusMode.FOCUS_NONE
	
	# Принудительно ставим стартовый цвет
	self.modulate = default_color
	
	# Подключаем сигналы мыши
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	# Плавно перетекаем из белого в фиолетовый
	var tween = create_tween()
	tween.tween_property(self, "modulate", hover_color, animate_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	# Плавно возвращаем белый
	var tween = create_tween()
	tween.tween_property(self, "modulate", default_color, animate_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
