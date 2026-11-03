shader_type canvas_item;

// Controls the intensity of the sharpening effect
uniform float sharpening_amount : hint_range(0.0, 5.0) = 1.0;
// Reads the final 3D rendered buffer directly

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Determine the size of a single pixel on screen
    vec2 pixel_size = SCREEN_PIXEL_SIZE;

    // Sample the center pixel
    vec4 center = texture(TEXTURE, uv);

    // Sample neighboring pixels (Up, Down, Left, Right)
    vec4 neighbor_up    = texture(TEXTURE, uv + vec2(0.0, -pixel_size.y));
    vec4 neighbor_down  = texture(TEXTURE, uv + vec2(0.0, pixel_size.y));
    vec4 neighbor_left  = texture(TEXTURE, uv + vec2(-pixel_size.x, 0.0));
    vec4 neighbor_right = texture(TEXTURE, uv + vec2(pixel_size.x, 0.0));

    // Simple Unsharp Mask kernel calculation
    // High-pass filter accentuates rapid differences between adjacent pixels
    vec4 sharp_color = center * (1.0 + 4.0 * sharpening_amount) - 
                       (neighbor_up + neighbor_down + neighbor_left + neighbor_right) * sharpening_amount;

    // Output the sharpened frame while clamping to protect color ranges
    COLOR = clamp(sharp_color, 0.0, 1.0);
}
