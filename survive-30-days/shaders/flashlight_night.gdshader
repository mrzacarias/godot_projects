shader_type canvas_item;

uniform vec2 bonfire_position = vec2(576.0, 324.0);
uniform float bonfire_radius = 150.0;
uniform vec2 flashlight_position = vec2(576.0, 324.0);
uniform vec2 flashlight_direction = vec2(1.0, 0.0);
uniform float flashlight_range = 200.0;
uniform float flashlight_cone_angle = 60.0; // degrees
uniform bool flashlight_active = false;
uniform vec2 screen_size = vec2(1152.0, 648.0);

void fragment() {
    vec2 screen_pos = SCREEN_UV * screen_size;
    
    // Check bonfire area
    float bonfire_dist = distance(screen_pos, bonfire_position);
    bool in_bonfire = bonfire_dist < bonfire_radius;
    
    // Check flashlight cone area
    bool in_flashlight = false;
    if (flashlight_active) {
        vec2 to_pixel = screen_pos - flashlight_position;
        float dist_to_flashlight = length(to_pixel);
        
        if (dist_to_flashlight <= flashlight_range) {
            // Normalize direction vectors
            vec2 normalized_direction = normalize(flashlight_direction);
            vec2 normalized_to_pixel = normalize(to_pixel);
            
            // Calculate angle between flashlight direction and pixel direction
            float dot_product = dot(normalized_direction, normalized_to_pixel);
            float angle_radians = acos(clamp(dot_product, -1.0, 1.0));
            float angle_degrees = degrees(angle_radians);
            
            // Check if pixel is within cone angle
            if (angle_degrees <= flashlight_cone_angle * 0.5) {
                in_flashlight = true;
            }
        }
    }
    
    // Create transparent holes where bonfire or flashlight illuminates, night color everywhere else
    if (in_bonfire || in_flashlight) {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0); // Transparent hole
    } else {
        COLOR = vec4(0.1, 0.15, 0.3, 0.6); // Night color (25% less dark)
    }
}
