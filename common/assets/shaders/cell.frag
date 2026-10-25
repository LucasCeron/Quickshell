#version 440

// Same membrane as mitosis.frag, for tiles of any rectangular size: two rounded
// boxes merged with a smooth union that stretches and pinches as they part.
// Draws a fill, an outline of `stroke` pixels, or both.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec4 cells;  // xy: mother center, zw: daughter center (pixels)
    vec4 halves; // xy: mother half size, zw: daughter half size (pixels)
    vec2 radii;  // x: mother, y: daughter corner radius (pixels)
    vec2 fade;   // x: mother, y: daughter; pushes a cell under the surface so it vanishes without leaving a dot
    float goo;   // smooth-union width: how far the membrane stretches before it splits
    float stroke;// outline width in pixels
    vec4 fill;
    vec4 outline;
};

float roundBox(vec2 p, vec2 center, vec2 half_size, float r) {
    vec2 q = abs(p - center) - half_size + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float smoothUnion(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float mother = roundBox(p, cells.xy, halves.xy, radii.x) + fade.x;
    float daughter = roundBox(p, cells.zw, halves.zw, radii.y) + fade.y;
    float d = smoothUnion(mother, daughter, goo);
    float inside = clamp(0.5 - d, 0.0, 1.0);
    float ring = inside * clamp(d + stroke + 0.5, 0.0, 1.0);
    // Qt hands colors over already premultiplied.
    vec4 line = outline * ring;
    vec4 body = fill * inside;
    fragColor = (line + body * (1.0 - line.a)) * qt_Opacity;
}
