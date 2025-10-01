#version 330

in vec2 fragPos;
out vec4 fragColor;

uniform vec2 iResolution;
uniform float iTime;
uniform vec2[70] iCards;

vec3 colors[5] = vec3[](
    vec3(0.4196, 0.5647, 0.5020),
    vec3(0.6431, 0.7647, 0.6980),
    vec3(0.8000, 0.8902, 0.8706),
    vec3(0.9176, 0.9569, 0.9569),
    vec3(0.9647, 1.0000, 0.9725)
);

float checkerboard(vec2 uv, int rows){
    float value = mod(floor(mod(uv.x*float(rows), 2.0)) + floor(mod(uv.y*float(rows), 2.0)), 2.0);
    return value;
}

vec3 mainImage(vec2 curr)
{
  int closest = 0;
  float dist = 999999;
  vec2 dir;

  vec2 uv = (curr/iResolution);
  for (int i = 0; i < 70; i++) {
    float len = abs(length(curr - iCards[i]));
    //if (len < dist) {
      dist = len;
      closest = i;
      dir = (curr - iCards[i]) / dist;
    //}

        uv = uv - (dir * (0.2 * dist)/(pow(dist, 1.2)+0.045)) / (dist / 30);
  }

  
  vec4 col1 = vec4(0.2275, 0.3529, 0.2510, 1);
  vec4 col2 = vec4(0.2039, 0.3059, 0.2549, 1);
  vec3 col = vec3(mix(col1, col2, checkerboard(uv, 50)));
  return col.xyz;
//
// bool isClose = dist < 200 ? true : false;
// float distf = dist < 400 ? (400 - dist) / 400 : 0;
//
// return isClose ? colors[closest % 5] : vec3(0.2, 0.2, 0.2);
}

void main() {
  vec2 uv = (fragPos * iResolution.xy).xy;
  fragColor = vec4(mainImage(uv).xyz, 1.0);
}
