extends Node3D

@export var letters_bend_force: float = 0.15
@export var stones_bend_force: float = 0.35
@export var smooth_speed: float = 5.0

@onready var letters_mesh: MeshInstance3D = %LettersMesh
@onready var stones_mesh: MeshInstance3D = %StonesMesh

var target_letters_rot: Vector3 = Vector3.ZERO
var target_stones_rot: Vector3 = Vector3.ZERO


func _process(delta: float) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var normalized_mouse := Vector2(
		(mouse_pos.x / viewport_size.x) * 2.0 - 1.0,
		(mouse_pos.y / viewport_size.y) * 2.0 - 1.0
	)

	target_letters_rot.y = -normalized_mouse.x * letters_bend_force
	target_letters_rot.x = -normalized_mouse.y * letters_bend_force
	target_stones_rot.y = -normalized_mouse.x * stones_bend_force
	target_stones_rot.x = -normalized_mouse.y * stones_bend_force

	if letters_mesh:
		letters_mesh.rotation.x = lerp(letters_mesh.rotation.x, target_letters_rot.x, delta * smooth_speed)
		letters_mesh.rotation.y = lerp(letters_mesh.rotation.y, target_letters_rot.y, delta * smooth_speed)
	if stones_mesh:
		stones_mesh.rotation.x = lerp(stones_mesh.rotation.x, target_stones_rot.x, delta * smooth_speed)
		stones_mesh.rotation.y = lerp(stones_mesh.rotation.y, target_stones_rot.y, delta * smooth_speed)
