shader_type canvas_item;

uniform vec2 offset_c = vec2(-1.5, 0.5);
uniform vec2 offset_m = vec2(1.5, -0.5);
uniform vec2 offset_y = vec2(0.0, 1.5);
uniform vec2 offset_k = vec2(0.0, 0.0);

uniform float dot_scale = 0.6;
uniform float smoothing_factor = 0.05;

uniform float bleed_radius : hint_range(0.0, 1.0) = 0.25;
uniform float bleed_softness : hint_range(0.0, 1.0) = 0.25;
uniform float bleed_strength : hint_range(0.0, 1.0) = 1.0;

// Ink weight for ONE channel only (mask selects C/M/Y/K).
// Uses the identity cmy = (max - rgb) / max, k = 1 - max, so no min() chain or branch.
float channel_weight(vec3 rgb, vec4 mask) {
    float m = max(rgb.r, max(rgb.g, rgb.b));
    return mask.a * (1.0 - m) + dot(mask.rgb, vec3(m) - rgb) / max(m, 0.0001);
}

float ink_coverage(vec2 p, ivec2 tex_max, vec4 mask, float max_r, float soft, sampler2D tex) {
    float col0 = floor(p.x);
    float clear = 1.0; // product of (1 - c): union of ink

    for (int dx = -1; dx <= 1; dx++) {
        float col = col0 + float(dx);
        float stripe = mod(col, 2.0);
        // only the two dots bracketing p.y in this column can reach the pixel
        float row0 = floor(p.y - 0.5 - 0.5 * stripe);

        for (int dy = 0; dy <= 1; dy++) {
            float row = row0 + float(dy);
            vec2 center = vec2(col + 0.5, row + 0.5 + 0.5 * stripe);

            // exact texel fetch, no UV math or filtering
            ivec2 ic = clamp(ivec2(int(col), int(row)), ivec2(0), tex_max);
            float weight = channel_weight(texelFetch(tex, ic, 0).rgb, mask);

            float radius = weight * max_r;
            float d = distance(p, center);

            // linear falloff instead of smoothstep
            float c = clamp((radius + soft - d) * (0.5 / soft), 0.0, 1.0);
            c *= step(0.001, weight);

            clear *= 1.0 - c;
        }
    }
    return 1.0 - clear;
}

void fragment() {
    ivec2 tex_size = textureSize(TEXTURE, 0);
    vec2 pixel_count = vec2(tex_size);
    ivec2 tex_max = tex_size - ivec2(1);
    vec2 base = UV * pixel_count;

    // hoisted: computed once instead of 4 times
    float max_r = dot_scale + bleed_radius * bleed_strength;
    float soft = max(mix(smoothing_factor, smoothing_factor + bleed_softness, bleed_strength), 0.001);

    float cC = ink_coverage(base + offset_c, tex_max, vec4(1.0, 0.0, 0.0, 0.0), max_r, soft, TEXTURE);
    float cM = ink_coverage(base + offset_m, tex_max, vec4(0.0, 1.0, 0.0, 0.0), max_r, soft, TEXTURE);
    float cY = ink_coverage(base + offset_y, tex_max, vec4(0.0, 0.0, 1.0, 0.0), max_r, soft, TEXTURE);
    float cK = ink_coverage(base + offset_k, tex_max, vec4(0.0, 0.0, 0.0, 1.0), max_r, soft, TEXTURE);

    vec3 rgb = clamp((vec3(1.0) - vec3(cC, cM, cY)) * (1.0 - cK), 0.1, 0.9);
    COLOR = vec4(rgb, texture(TEXTURE, UV).a);
}