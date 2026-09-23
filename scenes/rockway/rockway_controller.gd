extends Node3D

# Путь к материалу для всех камней
const MATERIAL_PATH = "res://shaders/island_material.tres"

# Уникальные тайминги (сдвиги во времени) для каждой группы
@export var offset_group_1: float = 0.0
@export var offset_group_2: float = 1.0
@export var offset_group_3: float = 2.0

# Общие настройки движения (можно менять в инспекторе)
@export var amplitude: float = 0.5
@export var speed: float = 0.8

# Переменные для хранения стартовых позиций групп
var bodies: Array[AnimatableBody3D] = []
var initial_positions: Array[Vector3] = []
var offsets: Array[float] = []

# Кастомный игровой таймер, защищённый от паузы
var internal_time: float = 0.0

func _ready() -> void:
	# 1. Загружаем материал
	var custom_material = load(MATERIAL_PATH)
	if not custom_material:
		push_error("Не найден материал по пути: " + MATERIAL_PATH)
	
	# Собираем массив сдвигов времени
	offsets = [offset_group_1, offset_group_2, offset_group_3]
	
	# 2. Ищем все AnimatableBody3D и их камни
	var _island_index = 0
	for child in get_children():
		if child is AnimatableBody3D:
			bodies.append(child)
			initial_positions.append(child.position)
			
			# Применяем материал ко всем MeshInstance3D внутри этой группы
			_apply_material_to_meshes(child, custom_material)
			_island_index += 1

func _apply_material_to_meshes(node: Node, mat: Material) -> void:
	if not mat: return
	for child in node.get_children():
		if child is MeshInstance3D:
			child.material_override = mat
		# Если камни лежат глубже в иерархии, ищем и там
		if child.get_child_count() > 0:
			_apply_material_to_meshes(child, mat)

func _physics_process(delta: float) -> void:
	# Накапливаем время на основе delta текущего кадра.
	# Во время паузы delta станет равна 0, и внутреннее время камней полностью замрёт!
	internal_time += delta
	
	# 3. Двигаем каждую группу физически корректно
	for i in range(bodies.size()):
		var body = bodies[i]
		var init_pos = initial_positions[i]
		var time_offset = offsets[i] if i < offsets.size() else 0.0
		
		# Считаем синусоиду на основе нашего замерзающего игрового времени
		var group_time = internal_time + time_offset
		var offset_y = sin(group_time * speed) * amplitude
		
		# Двигаем AnimatableBody3D
		body.position.y = init_pos.y + offset_y
