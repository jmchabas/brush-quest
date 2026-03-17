#version 460 core
precision mediump float;

#include <flutter/runtime_effect.glsl>

uniform float progress;    // 0.0 = start, 1.0 = fully expanded
uniform vec2 resolution;
uniform vec2 center;       // Impact point (normalized 0-1)
uniform vec3 ringColor;    // Color of the shockwave ring

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / resolution;

  // Distance from impact center
  float dist = length(uv - center);

  // Expanding ring radius
  float ringRadius = progress * 0.8;
  float ringWidth = 0.06 * (1.0 - progress); // Ring thins as it expands

  // Ring shape with soft edges
  float ring = smoothstep(ringRadius - ringWidth, ringRadius - ringWidth * 0.5, dist)
             - smoothstep(ringRadius + ringWidth * 0.5, ringRadius + ringWidth, dist);

  // Fade out as ring expands
  float fade = (1.0 - progress) * (1.0 - progress);

  // Inner bright core near the impact point (early in animation)
  float core = (1.0 - smoothstep(0.0, 0.15, dist)) * (1.0 - progress * 2.0);
  core = max(core, 0.0);

  float alpha = (ring * fade + core * 0.3);
  vec3 color = ringColor * (ring + core * 0.5);

  fragColor = vec4(color, alpha * 0.7);
}
