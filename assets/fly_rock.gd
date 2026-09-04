extends MeshInstance3D

var time = 0.0

# Настройки полета (можно менять)
var speed = 1.0     # Скорость движения
var amplitude = 0.2 # Высота полета (в метрах)

func _process(delta):
	time += delta
	# Двигаем камень вверх-вниз по синусоиде
	position.y += sin(time * speed) * amplitude * delta
