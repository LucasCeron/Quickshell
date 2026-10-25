#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec4 cells;  // xy: mother center, zw: daughter center (pixels)
    vec2 scales; // x: mother scale, y: daughter scale (1 = fills the whole tile)
    vec2 fade;   // x: mother, y: daughter; pushes a cell under the surface so it vanishes without leaving a dot
    float extent;// half the tile size at scale 1
    vec2 corners; // x: mother, y: daughter; corner radius as a fraction of the half size (1 = circle)
    float goo;   // smooth-union width: how far the membrane stretches before it splits
    vec4 tint;
};

float roundBox(vec2 p, vec2 center, float s, float roundness) {
    float r = extent * s * roundness;
    vec2 q = abs(p - center) - vec2(extent * s) + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float smoothUnion(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float mother = roundBox(p, cells.xy, scales.x, corners.x) + fade.x;
    float daughter = roundBox(p, cells.zw, scales.y, corners.y) + fade.y;
    float d = smoothUnion(mother, daughter, goo);
    float alpha = clamp(0.5 - d, 0.0, 1.0);
    fragColor = vec4(tint.rgb, 1.0) * tint.a * alpha * qt_Opacity;
}
