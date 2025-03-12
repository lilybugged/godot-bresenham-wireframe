shader_type spatial;
render_mode unshaded, cull_back;

void fragment() {
    // Compute edge detection using screen-space derivatives
    vec3 dFdxPos = dFdx(VERTEX);
    vec3 dFdyPos = dFdy(VERTEX);
    
    float edge_factor = length(cross(dFdxPos, dFdyPos));

    // Adjust the thickness of the wireframe
    float wire_thickness = 0.02;
    float wire = smoothstep(0.0, wire_thickness, edge_factor);

    // Colors: Mesh remains visible, wireframe overlays it
    vec3 base_color = vec3(0.3, 0.3, 0.3);  // Mesh color
    vec3 wire_color = vec3(1.0);            // Wireframe color

    ALBEDO = mix(wire_color, base_color, wire);
}
