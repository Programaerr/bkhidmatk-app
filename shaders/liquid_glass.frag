#version 460 core

// زجاج سائل فوق شريط التنقل: يكبّر ما تحته في الوسط، وعند حافته المنحنية ينكسر ما خلفه
// ويلمع، مثل زجاج الآيفون. يُستعمل مرشّحاً لما خلف الفقاعة (BackdropFilter).

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;        // يضعه المحرك: مقاس الصورة التي خلف الزجاج.
uniform vec4 uRect;        // الزجاج بالبكسل: يسار، أعلى، عرض، ارتفاع.
uniform float uRadius;     // انحناء الزوايا بالبكسل.
uniform float uZoom;       // تكبير الوسط.
uniform float uRefract;    // قوة الانكسار عند الحافة؛ صفر زجاج مستوٍ.
uniform float uPixel;      // كثافة الشاشة، لعرض لمعة الحافة.
uniform sampler2D uTexture; // يضعه المحرك: ما خلف الزجاج.

out vec4 fragColor;

// ما خلف الزجاج يأتي بنفس اتجاه الشاشة حتى مع OpenGLES، فلا يُقلب
// (قلبه أظهر أعلى الشاشة مقلوباً داخل الزجاج على هاتف Xiaomi).
vec4 backdrop(vec2 p) {
  return texture(uTexture, p / uSize);
}

// المسافة إلى حافة مستطيل مدوّر الزوايا: سالبة داخله.
float roundedBox(vec2 p, vec2 halfSize, float radius) {
  vec2 q = abs(p) - halfSize + radius;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 halfSize = uRect.zw * 0.5;
  vec2 centre = uRect.xy + halfSize;
  vec2 rel = frag - centre;
  float d = roundedBox(rel, halfSize, uRadius);
  if (d > 0.0) {
    fragColor = backdrop(frag);
    return;
  }

  // 0 في عمق الزجاج، و1 على حافته.
  float edge = 1.0 - clamp(-d / max(uRadius, 1.0), 0.0, 1.0);
  float bend = edge * edge * edge;

  // الوسط مكبّر، وقرب الحافة يمتد النظر إلى ما وراءها فينضغط فيها، كما في عدسة محدّبة.
  vec2 pos = centre + rel * (1.0 / uZoom + uRefract * bend);

  // فرق لون خفيف حيث ينكسر الضوء.
  vec2 fringe = normalize(rel + 0.0001) * bend * uRefract * 2.5 * uPixel;
  vec4 colour = vec4(
    backdrop(pos + fringe).r,
    backdrop(pos).g,
    backdrop(pos - fringe).b,
    1.0
  );

  // لمعة الضوء على الحافة، أقوى من الأعلى.
  float rim = 1.0 - smoothstep(0.0, 1.6 * uPixel, -d);
  vec2 dir = normalize(rel + 0.0001);
  float light = rim * (0.25 + 0.45 * clamp(-dir.y, 0.0, 1.0));
  colour.rgb = mix(colour.rgb, vec3(1.0), light);

  fragColor = colour;
}
