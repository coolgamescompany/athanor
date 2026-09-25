extends Node3D

# Скорость вращения (в радианах в секунду)
@export var rotation_speed: float = 2.0

func _process(delta: float) -> void:
	# Вращение вокруг вертикальной оси Y. 
	# Замените .y на .x или .z, если шестерёнка лежит в другой плоскости.
	rotate_z(rotation_speed * delta)
