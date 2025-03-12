shader_type spatial;

render_mode unshaded, cull_disabled;

uniform vec3 wire_color = vec3(1.0, 1.0, 1.0); // White color default
uniform float line_thickness : hint_range(0.1, 3.0) = 1.0;

void vertex() {
    VERTEX = VERTEX;
}

void fragment() {
    // Compute screen-space edge detection
    vec3 d = fwidth(VERTEX);
    vec3 edge_factor = smoothstep(vec3(0.0), d * line_thickness, abs(VERTEX));
    
    // Create sharp wireframe effect with no AA
    float wire = min(min(edge_factor.x, edge_factor.y), edge_factor.z);
    wire = 1.0 - wire;

    // Apply strict aliasing (sharp edges like Blender)
    ALBEDO = mix(vec3(0.0), wire_color, wire);
}
