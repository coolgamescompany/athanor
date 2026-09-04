shader_type spatial;

group_uniforms Grass_Settings;
uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic;

group_uniforms Stone_Settings;
uniform sampler2D stone_albedo : source_color, filter_linear_mipmap_anisotropic;

group_uniforms Global_Settings;
uniform float texture_scale : hint_range(0.01, 10.0) = 1.0;
uniform float blend_sharpness : hint_range(0.1, 10.0) = 2.0;

// Переменные для передачи чистых данных из vertex в fragment
varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	// Здесь VERTEX и NORMAL чисто локальные! Передаем их во фрагмент без искажений камеры.
	local_pos = VERTEX;
	local_normal = NORMAL;
}

vec3 get_triplanar_blend(sampler2D tex, vec3 p, vec3 n) {
	vec3 blending = abs(n);
	blending = normalize(max(blending, 0.00001));
	float sum = blending.x + blending.y + blending.z;
	blending /= vec3(sum);
	
	// Применяем масштаб к локальным координатам меша
	vec2 uv_x = p.zy * texture_scale;
	vec2 uv_y = p.xz * texture_scale;
	vec2 uv_z = p.xy * texture_scale;
	
	vec3 x_tex = texture(tex, uv_x).rgb;
	vec3 y_tex = texture(tex, uv_y).rgb;
	vec3 z_tex = texture(tex, uv_z).rgb;
	
	return x_tex * blending.x + y_tex * blending.y + z_tex * blending.z;
}

void fragment() {
	// Используем переданные чистые локальные координаты
	vec3 g_alb = get_triplanar_blend(grass_albedo, local_pos, local_normal);
	vec3 s_alb = get_triplanar_blend(stone_albedo, local_pos, local_normal);
	
	// Рассчитываем маску верха по локальной нормали модели
	float blend_mask = clamp(dot(normalize(local_normal), vec3(0.0, 1.0, 0.0)) * blend_sharpness, 0.0, 1.0);
	
	ALBEDO = mix(s_alb, g_alb, blend_mask);
	ROUGHNESS = 1.0; 
}
