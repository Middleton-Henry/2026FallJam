shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec4 sample = texture(TEXTURE, UV);
	COLOR = sample;
}
