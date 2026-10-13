#version 440
// Rounded-rect border whose colour sweeps around the shape, plus a soft outer halo.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;      // 0..1 loop
    float w;
    float h;
    float pad;       // space reserved around the box for the halo
    float radius;
    float thickness;
    float glow;      // 0..1
    vec4 c1;
    vec4 c2;
    vec4 c3;
    vec4 c4;
};

float sdRoundBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

vec3 palette(float t) {
    t = fract(t) * 4.0;
    if (t < 1.0) return mix(c1.rgb, c2.rgb, smoothstep(0.0, 1.0, t));
    if (t < 2.0) return mix(c2.rgb, c3.rgb, smoothstep(0.0, 1.0, t - 1.0));
    if (t < 3.0) return mix(c3.rgb, c4.rgb, smoothstep(0.0, 1.0, t - 2.0));
    return mix(c4.rgb, c1.rgb, smoothstep(0.0, 1.0, t - 3.0));
}

void main() {
    vec2 size = vec2(w, h);
    vec2 p = qt_TexCoord0 * size - size * 0.5;
    vec2 b = size * 0.5 - vec2(pad);
    float r = min(radius, min(b.x, b.y));
    float d = sdRoundBox(p, b, r);

    float ang = atan(p.y * (b.x / max(b.y, 1.0)), p.x) / 6.2831853 + 0.5;
    vec3 col = palette(ang + time);

    float half_t = thickness * 0.5;
    float line = 1.0 - smoothstep(half_t - 0.7, half_t + 0.7, abs(d + half_t));
    float halo = glow * exp(-max(d, 0.0) / max(pad * 0.32, 0.5)) * step(0.0, d) * 0.6;
    float a = clamp(line + halo, 0.0, 1.0);
    fragColor = vec4(col * a, a) * qt_Opacity;
}
