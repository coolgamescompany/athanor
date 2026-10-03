extends Node
## SceneLoader — асинхронная загрузка сцен через ResourceLoader.
##
## Заменяет синхронные get_tree().change_scene_to_file() / reload_current_scene():
## сцена читается с диска в фоновом потоке, а пока идёт загрузка, экран плавно
## затемняется. Игра не зависает и не «белеет» при переходах между уровнями.

signal transition_started(scene_path: String)
signal transition_finished(scene_path: String)

## Слой оверлея: поверх всего (HUD, шейдеры и т.п.).
const OVERLAY_LAYER: int = 100

## Время плавного затемнения / проявления.
const FADE_OUT_TIME: float = 0.25
const FADE_IN_TIME: float = 0.35

var _fade_rect: ColorRect
var _is_transitioning: bool = false


func _ready() -> void:
	# Автозагрузка должна работать даже когда игра на паузе (выход в меню из паузы).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = OVERLAY_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "SceneFadeRect"
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade_rect)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# ЦветRect создаётся с дефолтным минимальным размером — после добавления в дерево
	# и первого кадра он растянется на весь вьюпорт, но на всякий случай сразу привяжемся.
	get_tree().root.size_changed.connect(_update_overlay_size)
	_update_overlay_size.call_deferred()


func _update_overlay_size() -> void:
	if _fade_rect and is_instance_valid(_fade_rect):
		_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fade_rect.size = get_viewport().get_visible_rect().size


## Асинхронная смена сцены (путь к .tscn): затемнение -> фоновая загрузка -> смена -> проявление.
func change_scene_async(scene_path: String) -> void:
	if _is_transitioning:
		return
	if scene_path.is_empty():
		push_error("SceneLoader: пустой путь к сцене.")
		return
	if not ResourceLoader.exists(scene_path):
		push_error("SceneLoader: ресурс не найден: %s" % scene_path)
		return

	_is_transitioning = true
	transition_started.emit(scene_path)

	# 1) Прячем «белый» кадр за плавным затемнением — уже на этом этапе игра не зависает,
	#    потому что ничего не загружаем главным потоком.
	await _fade_to(1.0, FADE_OUT_TIME)
	if not is_inside_tree():
		return

	# 2) Запускаем фоновую загрузку в отдельном потоке (use_sub_threads = true).
	var error: Error = ResourceLoader.load_threaded_request(scene_path, "PackedScene", true)
	if error != OK:
		push_error("SceneLoader: не удалось начать загрузку '%s' (код %d)" % [scene_path, error])
		await _fade_to(0.0, FADE_IN_TIME)
		_is_transitioning = false
		return

	# 3) Аккуратно «поллим» статус по одному разу за кадр — интерфейс/игра продолжают дышать.
	while true:
		if not is_inside_tree():
			return
		var status: int = ResourceLoader.load_threaded_get_status(scene_path)
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			break
		await get_tree().process_frame

	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(scene_path)
	if packed_scene == null:
		push_error("SceneLoader: не удалось загрузить сцену '%s'" % scene_path)
		await _fade_to(0.0, FADE_IN_TIME)
		_is_transitioning = false
		return

	# 4) Смена сцены: ресурс уже полностью в памяти, поэтому change_scene_to_packed быстрый.
	transition_finished.emit(scene_path)
	get_tree().change_scene_to_packed(packed_scene)

	# 5) Даём новой сцене пару кадров на первый рендер и плавно открываемся.
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0, FADE_IN_TIME)
	_is_transitioning = false


## Асинхронный перезапуск текущей сцены.
func reload_current_scene() -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var scene_path: String = get_tree().current_scene.scene_file_path
	if scene_path.is_empty():
		return
	change_scene_async(scene_path)


func _fade_to(target_alpha: float, duration: float) -> void:
	if _fade_rect == null:
		return
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade_rect, "color:a", target_alpha, duration)
	await tween.finished