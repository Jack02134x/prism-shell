#version 440
// Flowing aurora ribbons over a base colour. `time` loops 0..1 seamlessly.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float w;
    float h;
    float intensity;
    vec4 c1;
    vec4 c2;
    vec4 c3;
    vec4 bg;
};

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = w / max(h, 1.0);
    vec2 p = vec2(uv.x * aspect, uv.y);
    float t = time * 6.2831853;
    vec2 loop = vec2(cos(t), sin(t)) * 0.55;

    float n1 = fbm(p * 1.4 + loop);
    float n2 = fbm(p * 2.1 - loop.yx + n1 * 1.3);
    float n3 = fbm(p * 0.9 + vec2(loop.y, -loop.x) * 1.4 + n2);

    float y1 = 0.38 + (n1 - 0.5) * 0.7;
    float y2 = 0.62 + (n2 - 0.5) * 0.8;
    float band1 = exp(-pow((uv.y - y1) * 5.0, 2.0));
    float band2 = exp(-pow((uv.y - y2) * 4.0, 2.0));
    float curtain = smoothstep(0.35, 0.85, fbm(vec2(uv.x * aspect * 6.0 + n3 * 2.0, uv.y * 0.6) + loop * 0.4));

    vec3 col = bg.rgb;
    col = mix(col, c1.rgb, band1 * (0.55 + 0.45 * curtain) * intensity);
    col = mix(col, c2.rgb, band2 * (0.45 + 0.55 * (1.0 - curtain)) * intensity * 0.85);
    col += c3.rgb * pow(n3, 4.0) * intensity * 0.9;

    // tiny stars
    vec2 sp = floor(uv * vec2(w, h) / 3.0);
    float star = step(0.9975, hash(sp)) * (0.5 + 0.5 * sin(t * 3.0 + hash(sp + 3.0) * 30.0));
    col += vec3(star) * 0.6 * intensity;

    float vig = smoothstep(1.15, 0.25, length((uv - 0.5) * vec2(1.0, 1.2)));
    col *= mix(0.7, 1.0, vig);

    float a = bg.a;
    fragColor = vec4(col * a, a) * qt_Opacity;
}
