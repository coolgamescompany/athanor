extends Camera3D

# =====================================================================
# === ГЛАВНЫЙ МОДУЛЬ УПРАВЛЕНИЯ ЭФФЕКТАМИ КАМЕРЫ ПЕРСОНАЖА (CAMERA) ===
# =====================================================================


# --- НАСТРОЙКИ ЭФФЕКТА ИНЕРЦИОННОГО ДЫХАНИЯ (СТОИМ НА МЕСТЕ) ---
@export var IDLE_BOB_SPEED: float = 3.0       # Скорость ленивого дыхания (чуть быстрее)
@export var IDLE_BOB_AMOUNT: float = 0.02    # Амплитуда дыхания (около 1.5 см — теперь покачивание в простое чётко видно глазами)

# --- НАСТРОЙКИ ЭФФЕКТА ДИНАМИЧЕСКИХ ШАГОВ (ХОДЬБА / БЕГ) ---
@export var WALK_BOB_SPEED: float = 14.0     # Частота шагов (ритм шагов стал более чётким и естественным)
@export var WALK_BOB_AMOUNT: float = 0.1     # Амплитуда вверх-вниз (голова качается на ~8 см, создавая честное ощущение массы тела)
@export var WALK_BOB_SIDE: float = 0.1       # Амплитуда влево-вправо (мягкий стрейф при переносе веса с ноги на ногу)

   

# --- СИСТЕМНЫЕ КОМПОНЕНТЫ И КЭШ КОРДИНАТ ---
var time_passed: float = 0.0
var parent_player: CharacterBody3D
var base_y: float = 0.0

func _ready() -> void:
	parent_player = get_parent() as CharacterBody3D
	if parent_player:
		base_y = parent_player.camera_default_y

func _process(delta: float) -> void:
	if parent_player and parent_player.is_intro_playing:
		return
		
	time_passed += delta
	var is_moving: bool = parent_player and parent_player.velocity.length() > 0.1 and parent_player.is_on_floor()
	
	if parent_player:
		base_y = (parent_player.CROUCH_HEIGHT * 0.5) if parent_player.is_crouching else parent_player.camera_default_y
	
	var target_pos_y: float = base_y
	var target_pos_x: float = 0.0
	
	if is_moving:
		# --- РЕЖИМ ХОДЬБЫ / БЕГА (ДИНАМИЧЕСКИЙ МАСШТАБ) ---
		# Рассчитываем коэффициент скорости (при беге на Shift он будет равен ~1.7)
		var speed_factor = parent_player.velocity.length() / parent_player.WALK_SPEED
		var current_bob_speed = WALK_BOB_SPEED * speed_factor
		
		# ГЕЙМДЕВ-ТРЮК: Чем быстрее бежит алхимик, тем сильнее амплитуда шага!
		var dynamic_amount = WALK_BOB_AMOUNT * speed_factor
		var dynamic_side = WALK_BOB_SIDE * speed_factor
		
		# Траектория "Восьмерки" с учётом динамической силы шага
		target_pos_y = base_y + sin(time_passed * current_bob_speed) * dynamic_amount
		target_pos_x = cos(time_passed * current_bob_speed * 0.5) * dynamic_side
	else:
		target_pos_y = base_y + sin(time_passed * IDLE_BOB_SPEED) * IDLE_BOB_AMOUNT
		target_pos_x = cos(time_passed * IDLE_BOB_SPEED * 0.5) * IDLE_BOB_AMOUNT
	
	position.y = lerp(position.y, target_pos_y, delta * 10.0)
	position.x = lerp(position.x, target_pos_x, delta * 10.0)
