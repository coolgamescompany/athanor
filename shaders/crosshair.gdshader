shader_type canvas_item;

void fragment() {
	float dist = distance(UV, vec2(0.5));
	// Сглаживаем края круга
	float alpha = 1.0 - smoothstep(0.5 - fwidth(dist), 0.5, dist);
	COLOR.a *= alpha;
}
