#version 440
// Wobbling plasma orb; `level` (0..1) makes it react to audio.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float level;
    vec4 c1;
    vec4 c2;
    vec4 c3;
};

void main() {
    vec2 uv = qt_TexCoord0 * 2.0 - 1.0;
    float r = length(uv);
    float a = atan(uv.y, uv.x);
    float t = time * 6.2831853;

    float wob = 0.05 * sin(a * 3.0 + t * 2.0)
              + 0.04 * sin(a * 5.0 - t * 3.0)
              + level * 0.10 * sin(a * 7.0 + t * 5.0);
    float edge = 0.70 + wob + level * 0.08;
    float inside = 1.0 - smoothstep(edge - 0.035, edge + 0.035, r);

    float swirl = 0.5 + 0.5 * sin(a * 2.0 + r * 7.0 - t * 4.0);
    float swirl2 = 0.5 + 0.5 * sin(a * 3.0 - r * 5.0 + t * 2.0);
    vec3 col = mix(c1.rgb, c2.rgb, swirl);
    col = mix(col, c3.rgb, swirl2 * smoothstep(0.1, 0.75, r) * 0.7);
    float spec = pow(max(0.0, 1.0 - length(uv - vec2(-0.28, -0.32)) * 2.4), 3.0);
    col += vec3(spec) * 0.7;

    float glow = exp(-max(r - edge, 0.0) * 7.0) * (1.0 - inside) * (0.35 + level * 0.5);
    float alpha = clamp(inside + glow, 0.0, 1.0);
    vec3 outc = mix(mix(c1.rgb, c2.rgb, 0.5), col, inside);
    fragColor = vec4(outc * alpha, alpha) * qt_Opacity;
}
