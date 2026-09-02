shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 0.0;
uniform float white_fade : hint_range(0.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.0;

void fragment() {
	// 1. Берем картинку с экрана и размываем её
	vec4 scene_color = textureLod(screen_texture, SCREEN_UV, blur_amount);
	
	// 2. Настраиваем контрастность (зрение стабилизируется)
	scene_color.rgb = (scene_color.rgb - 0.5) * contrast + 0.5;
	
	// 3. Плавно подмешиваем белый цвет вспышки
	COLOR.rgb = mix(scene_color.rgb, vec3(1.0), white_fade);
	COLOR.a = 1.0; // Экран всегда полностью перекрывает 3D-мир
}
