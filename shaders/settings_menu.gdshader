shader_type canvas_item;

// Загружаем текстуру экрана с жесткой генерацией Mip-карт для размытия панорам
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Сила размытия (4.0 - глубокое матовое стекло, размоет даже скайбокс)
uniform float blur_amount : hint_range(0.0, 5.0) = 4.0;
// Затемнение (0.4 = глубокий полумрак)
uniform float brightness : hint_range(0.0, 2.0) = 0.4;
// Понижение контраста (0.7 = сглаживает резкие пиксели панорамы)
uniform float contrast : hint_range(0.0, 2.0) = 0.7;
// Космический оттенок
uniform vec4 tint_color : source_color = vec4(0.08, 0.03, 0.16, 0.55);

void fragment() {
	// 1. Принудительно считываем и размываем абсолютно ВСЁ, что видит камера
	vec4 tex = textureLod(screen_texture, SCREEN_UV, blur_amount);
	
	// 2. Математика понижения контраста и яркости на всем экране
	tex.rgb = mix(vec3(0.5), tex.rgb * brightness, contrast);
	
	// 3. Финальное наложение тёмно-пурпурной алхимической дымки
	COLOR = mix(tex, tint_color, tint_color.a);
}
