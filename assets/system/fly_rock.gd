extends MeshInstance3D

var time: float = 0.0
@export var speed: float = 1.0
@export var amplitude: float = 0.2


func _process(delta: float) -> void:
	time += delta
	position.y += sin(time * speed) * amplitude * delta
