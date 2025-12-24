shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(uv, center);

	// 圆形裁剪
	if (dist > 0.5) {
		COLOR.a = 0.0;
	} else {
		COLOR = texture(TEXTURE, UV);
		// 边缘柔化
		float edge = smoothstep(0.5, 0.48, dist);
		COLOR.a *= edge;
	}
}
