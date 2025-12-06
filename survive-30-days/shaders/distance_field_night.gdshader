shader_type canvas_item;

uniform vec2 bonfire_position = vec2(576.0, 324.0);
uniform float bonfire_radius = 150.0;
uniform vec2 screen_size = vec2(1152.0, 648.0);

void fragment() {
    vec2 screen_pos = SCREEN_UV * screen_size;
    float dist = distance(screen_pos, bonfire_position);
    
    // Create transparent hole where bonfire is, night color everywhere else
    if (dist < bonfire_radius) {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0); // Transparent hole
    } else {
        COLOR = vec4(0.1, 0.15, 0.3, 0.6); // Night color (25% less dark)
    }
}
