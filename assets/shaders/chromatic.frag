#version 460 core
precision mediump float;

#include <flutter/runtime_effect.glsl>

uniform float intensity;   // 0.0 = normal, 1.0 = max aberration
uniform vec2 resolution;
uniform sampler2D image;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / resolution;

  // Direction from center
  vec2 dir = uv - vec2(0.5);

  // Offset amount based on intensity and distance from center
  float offset = intensity * 0.015 * length(dir);
  vec2 rOffset = dir * offset;
  vec2 bOffset = -dir * offset;

  // Sample each channel with different offsets
  float r = texture(image, uv + rOffset).r;
  float g = texture(image, uv).g;
  float b = texture(image, uv + bOffset).b;
  float a = texture(image, uv).a;

  fragColor = vec4(r, g, b, a);
}
