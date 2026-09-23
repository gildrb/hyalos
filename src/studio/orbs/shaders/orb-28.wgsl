// Compiled from unchanged shadercn orb-28 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 3f269a2eb2d324ec341c39fcef42c8695b4e583e605a2990607213a8a7a0b301
struct orb28Params {
  anim: f32,
  c_base: vec3f,
  c_lineA: vec3f,
  c_lineB: vec3f,
  c_rim: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_body: f32,
  p_contrast: f32,
  p_edge: f32,
  p_edgeFade: f32,
  p_gain: f32,
  p_gridScale: f32,
  p_levels: f32,
  p_lineW: f32,
  p_radius: f32,
  p_rim: f32,
  p_rimPow: f32,
  p_shutter: f32,
  p_speed: f32,
  p_spin: f32,
  p_tilt: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb28Params;

fn rot2(angle: f32) -> mat2x2f {
  let c = cos(angle);
  let s = sin(angle);
  return mat2x2f(vec2f(c, -(s)), vec2f(s, c));
}

struct orb28Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb28Fragment(_arg_0: orb28Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let bitdumbGain = ((*u).p_gain * (1f + (0.6f * (*u).inputVol)));
  let bitdumbBody = ((*u).p_body * (1f + (0.8f * (*u).outputVol)));
  let duv = (orbUv / (*u).p_radius);
  let r2 = dot(duv, duv);
  let band = mix(0.35f, 0.012f, clamp((*u).p_edge, 0f, 1f));
  let mask = (1f - smoothstep((1f - band), 1.005f, length(duv)));
  let zc = sqrt(max((1f - r2), 0f));
  let n = vec3f(duv, zc);
  var sp = n;
  let tilted = (rot2((*u).p_tilt) * vec2f(sp.y, sp.z));
  sp = vec3f(sp.x, tilted.x, tilted.y);
  let spun = (rot2((*u).p_spin) * vec2f(sp.x, sp.z));
  sp = vec3f(spun.x, sp.y, spun.y);
  var p = ((sp.xy / (abs(sp.z) + 1f)) * (*u).p_gridScale);
  var px = ((((2f / min((*u).res.x, (*u).res.y)) / (*u).p_radius) / max(zc, 0.2f)) * (*u).p_gridScale);
  var acc = vec4f();
  let phase = ((*u).p_speed * 0.2f);
  for (var i = 0u; i < 20u; i += 1u) {
    let fi = (f32(i) + 1f);
    if ((fi > (*u).p_levels)) {
      break;
    }
    p = (p + p);
    px += px;
    let v = ceil(p);
    let f = fract(p);
    let e2 = (vec2f(1) - smoothstep(vec2f(), vec2f((px * (*u).p_lineW)), min(f, (vec2f(1) - f))));
    let edgeCol = (((*u).c_lineA * e2.x) + ((*u).c_lineB * e2.y));
    let aBit = (fract(((length(v) / fi) - phase)) * (*u).p_shutter);
    acc = (acc + (vec4f(edgeCol, aBit) * (1f - acc.w)));
    if ((acc.w > 0.996f)) {
      break;
    }
  }
  var col = (acc.xyz * bitdumbGain);
  let L = vec3f(-0.4056161046028137, 0.507020115852356, 0.7605301737785339);
  let shade = (0.25f + (0.75f * clamp(dot(n, L), 0f, 1f)));
  col = (col + ((*u).c_base * (shade * bitdumbBody)));
  col = (col + ((*u).c_rim * (pow((1f - zc), (*u).p_rimPow) * (*u).p_rim)));
  col = pow(max(col, vec3f()), vec3f((*u).p_contrast));
  let fade = (1f - smoothstep((*u).p_edgeFade, 1f, length(orbUv)));
  let a = (mask * fade);
  return vec4f((col * a), a);
}
