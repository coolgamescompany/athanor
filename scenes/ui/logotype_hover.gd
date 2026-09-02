extends Node3D

# Настройки силы поворота (коэффициенты параллакса)
@export var letters_bend_force: float = 0.15  # Сила наклона букв
@export var stones_bend_force: float = 0.35   # Камни летают свободнее, поэтому делаем им силу больше!
@export var smooth_speed: float = 5.0         # Скорость плавного возврата/поворота

# Ссылки на две части твоей модели
@onready var letters_mesh: MeshInstance3D = %LettersMesh
@onready var stones_mesh: MeshInstance3D = %StonesMesh

# Переменные для хранения целей вращения
var target_letters_rot: Vector3 = Vector3.ZERO
var target_stones_rot: Vector3 = Vector3.ZERO

func _process(delta: float) -> void:
	# 1. Получаем размеры окна игры
	var window_size := Vector2(get_viewport().get_window().size)
	
	# 2. Получаем позицию курсора мыши
	var mouse_pos := get_viewport().get_mouse_position()
	
	# 3. Переводим координаты мыши в диапазон от -1.0 до 1.0 (где 0.0 — ровно центр экрана)
	var normalized_mouse := Vector2(
		(mouse_pos.x / window_size.x) * 2.0 - 1.0,
		(mouse_pos.y / window_size.y) * 2.0 - 1.0
	)
	
	# 4. Считаем целевой угол поворота по осям X и Y для каждой части
	# При движении мыши по X — модель крутится по оси Y (влево-вправо)
	# При движении мыши по Y — модель крутится по оси X (вверх-вниз)
	target_letters_rot.y = -normalized_mouse.x * letters_bend_force
	target_letters_rot.x = -normalized_mouse.y * letters_bend_force
	
	target_stones_rot.y = -normalized_mouse.x * stones_bend_force
	target_stones_rot.x = -normalized_mouse.y * stones_bend_force
	
	# 5. Плавное перетекание (Lerp) текущего поворота к целевому, чтобы не было резких дёрганий
	if letters_mesh:
		letters_mesh.rotation.x = lerp(letters_mesh.rotation.x, target_letters_rot.x, delta * smooth_speed)
		letters_mesh.rotation.y = lerp(letters_mesh.rotation.y, target_letters_rot.y, delta * smooth_speed)
		
	if stones_mesh:
		stones_mesh.rotation.x = lerp(stones_mesh.rotation.x, target_stones_rot.x, delta * smooth_speed)
		stones_mesh.rotation.y = lerp(stones_mesh.rotation.y, target_stones_rot.y, delta * smooth_speed)
