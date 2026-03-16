#version 460 core
precision mediump float;

#include <flutter/runtime_effect.glsl>

uniform float progress;    // 0.0 = fully visible, 1.0 = fully dissolved
uniform vec2 resolution;

out vec4 fragColor;

// Hash-based noise for dissolve pattern
float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / resolution;

  // Multi-scale noise for organic dissolve edges
  float noise = hash(uv * 15.0) * 0.6 + hash(uv * 30.0) * 0.3 + hash(uv * 60.0) * 0.1;

  // Distance from center — dissolve from edges inward
  vec2 center = vec2(0.5, 0.5);
  float dist = length(uv - center) * 1.2;
  float edgeBias = noise * 0.7 + dist * 0.3;

  // Dissolve edge with smooth transition
  float edge = smoothstep(progress - 0.08, progress + 0.02, edgeBias);

  // Glow at dissolve boundary
  float glow = smoothstep(progress - 0.12, progress - 0.03, edgeBias)
             - smoothstep(progress - 0.03, progress + 0.02, edgeBias);

  // Orange/yellow glow at dissolve edge, white core
  vec3 glowColor = vec3(1.0, 0.55, 0.1) * glow * 4.0;
  vec3 coreGlow = vec3(1.0, 1.0, 0.8) * glow * 2.0;

  vec3 color = vec3(1.0) + glowColor + coreGlow;
  fragColor = vec4(color, edge);
}
