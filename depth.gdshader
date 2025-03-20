// Godot 4.3, Forward+ or Mobile
shader_type spatial;
render_mode unshaded, fog_disabled;

uniform sampler2D screen_texture : source_color, hint_screen_texture;
uniform sampler2D depth_texture : hint_depth_texture;
uniform sampler2D normal_rough_texture : hint_normal_roughness_texture;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec4 screen = texture(screen_texture, SCREEN_UV);
	
	float depth_raw = texture(depth_texture, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 position_view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	position_view.xyz /= position_view.w;
	float linear_depth = -position_view.z;
	
	vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 position_world = world.xyz / world.w;
	
	vec4 normal_rough = texture(normal_rough_texture, SCREEN_UV);
	vec3 normals_view_raw = normal_rough.xyz; // Normals in view space, in [0.0, 1.0] range
	vec3 normals_view_remapped = normals_view_raw.xyz * 2.0 - 1.0;  // Normals in view space, in [-1.0, 1.0] range
	vec3 normals_world = (INV_VIEW_MATRIX * vec4(normals_view_remapped, 0.0)).xyz;
	float roughness = normal_rough.w;
	
	// Visualize the outputs
	// Screen texture
	//ALBEDO.rgb = screen.rgb;
	// Raw depth
	//ALBEDO.rgb = vec3(depth_raw);
	// Linear depth
	ALBEDO.rgb = vec3(fract(linear_depth));
	// World position
	//ALBEDO.rgb = fract(position_world);	
	// Normals from the normal buffer, in view space
	//ALBEDO.rgb = normals_view_raw;
	// Normals in world space, [-1.0,1.0] range
	//ALBEDO.rgb = normals_world;
	// Roughness
	//ALBEDO.rgb = vec3(roughness);
}