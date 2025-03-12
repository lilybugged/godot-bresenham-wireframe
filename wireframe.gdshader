shader_type spatial;
render_mode unshaded, skip_vertex_transform;

uniform float time;
const float one = 1.0;
//const float PI = 3.14159265359;
const float TWO_PI = 2.0 * PI;
const vec4 line_color = vec4(0.0, 1.0, 0.0, 1.0);
const vec4 background_color = vec4(0.0, 0.0, 0.0, 1.0);

void vertex() {
	//float offset = mod(TIME * 1.5, TWO_PI);
	//float offset2 = mod(TIME * 2.0, TWO_PI);
	//VERTEX.z += mod(TIME * 2.0, 1.0);
	//VERTEX.y = sin(VERTEX.x * 0.5 + offset) * 0.5 + sin(VERTEX.z + offset2) * 0.2;
	COLOR = mix(line_color, background_color, -(VERTEX.z) * 0.1 + 0.1);
    VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = COLOR.rgb;
}