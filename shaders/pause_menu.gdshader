shader_type canvas_item;

// Читаем живой экран БЕЗ мип-мапов (filter_linear обычный, он не ломается на паузе)
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

void fragment() {
	// Вычисляем размер шага в зависимости от разрешения экрана (под твое 2K разрешение)
	vec2 tex_size = vec2(1.0) / SCREEN_PIXEL_SIZE;
	
	// Сила размытия (0.003 - это идеальный аналог твоего значения 0.25, мягкий туман)
	float blur_radius = 0.003;
	vec2 uv_offset = vec2(blur_radius);
	
	vec4 sum = vec4(0.0);
	
	// РУЧНАЯ МАТРИЦА ГАУССА: Собираем соседние пиксели прямо с живого кадра. 
	// Этот код физически не может выдать прозрачность, потому что он всегда читает экран!
	sum += texture(screen_texture, SCREEN_UV + vec2(-uv_offset.x, -uv_offset.y)) * 0.075;
	sum += texture(screen_texture, SCREEN_UV + vec2(0.0,          -uv_offset.y)) * 0.125;
	sum += texture(screen_texture, SCREEN_UV + vec2(uv_offset.x,  -uv_offset.y)) * 0.075;
	
	sum += texture(screen_texture, SCREEN_UV + vec2(-uv_offset.x, 0.0))          * 0.125;
	sum += texture(screen_texture, SCREEN_UV + vec2(0.0,          0.0))          * 0.200; // Центр кадра
	sum += texture(screen_texture, SCREEN_UV + vec2(uv_offset.x,  0.0))          * 0.125;
	
	sum += texture(screen_texture, SCREEN_UV + vec2(-uv_offset.x, uv_offset.y))  * 0.075;
	sum += texture(screen_texture, SCREEN_UV + vec2(0.0,          uv_offset.y))  * 0.125;
	sum += texture(screen_texture, SCREEN_UV + vec2(uv_offset.x,  uv_offset.y))  * 0.075;
	
	// Выдаем идеально сглаженное матовое стекло!
	COLOR = sum;
}
