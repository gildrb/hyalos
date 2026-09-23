// Compiled from unchanged shadercn orb-33 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 6e1f1c74526815497d91c34df5124418f9111b3f81c40269a1c3a5c605fe940a
struct orb33Params {
  anim: f32,
  c_cold: vec3f,
  c_cool: vec3f,
  c_core: vec3f,
  c_hot: vec3f,
  c_paper: vec3f,
  c_warm: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_banding: f32,
  p_bands: f32,
  p_contrast: f32,
  p_dither: f32,
  p_dotGain: f32,
  p_dotSoft: f32,
  p_dots: f32,
  p_freq: f32,
  p_gain: f32,
  p_grain: f32,
  p_grainSize: f32,
  p_hi: f32,
  p_ink: f32,
  p_jitter: f32,
  p_light: f32,
  p_lo: f32,
  p_misregister: f32,
  p_printMix: f32,
  p_radius: f32,
  p_rim: f32,
  p_scale: f32,
  p_speed: f32,
  p_spin: f32,
  p_warp: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb33Params;

fn hash(p: vec2f) -> f32 {
  return fract((sin(dot(p, vec2f(127.0999984741211, 311.70001220703125))) * 43758.5453123f));
}

fn noise(p: vec2f) -> f32 {
  let i = floor(p);
  let f = fract(p);
  let ff = ((f * f) * (vec2f(3) - (f * 2f)));
  return mix(mix(hash(i), hash((i + vec2f(1, 0))), ff.x), mix(hash((i + vec2f(0, 1))), hash((i + vec2f(1))), ff.x), ff.y);
}

fn grainNoise(gpix: vec2f, frame: f32, seed: f32) -> f32 {
  return hash((gpix + vec2f(((frame * 13.71f) + seed), ((frame * 7.37f) - seed))));
}

fn rot2(angle: f32) -> mat2x2f {
  let c = cos(angle);
  let s = sin(angle);
  return mat2x2f(vec2f(c, -(s)), vec2f(s, c));
}

fn screen(uv: vec2f, a: f32, o: vec2f, coverage: f32, soft: f32) -> f32 {
  let u = (&params);
  let cell = (((rot2(a) * uv) * (*u).p_dots) + o);
  let f = (fract(cell) - 0.5f);
  let dist = length(f);
  let size = (0.5f * sqrt(clamp((coverage * (*u).p_dotGain), 0f, 1f)));
  return (1f - smoothstep((size - soft), (size + soft), dist));
}

struct orb33Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb33Fragment(_arg_0: orb33Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let heatGainNow = ((*u).p_gain * (1f + (0.6f * (*u).outputVol)));
  let heatJitterNow = ((*u).p_jitter * (1f + (1.5f * (*u).inputVol)));
  let rd = length(orbUv);
  let R = (*u).p_radius;
  let mask = smoothstep(0.012f, -0.012f, (rd - R));
  if ((mask <= 0f)) {
    return vec4f();
  }
  let pl = (orbUv / R);
  let r2 = dot(pl, pl);
  let z = sqrt(max((1f - r2), 0f));
  let n = vec3f(pl, z);
  let cr = cos((*u).p_spin);
  let sr = sin((*u).p_spin);
  let sp = vec3f(((n.x * cr) - (n.z * sr)), n.y, ((n.x * sr) + (n.z * cr)));
  let t = (*u).p_speed;
  let st = ((sp.xy / (1.3f + sp.z)) * (*u).p_scale);
  var p = ((st * (*u).p_freq) + vec2f((t * 0.11f), (-(t) * 0.07f)));
  let wp = ((st * ((*u).p_freq * 0.55f)) + vec2f((-(t) * 0.05f), (t * 0.08f)));
  let warp = (vec2f(noise((wp + 3.1f)), noise((wp + 9.4f))) - 0.5f);
  p = (p + (warp * (*u).p_warp));
  p = (p + (vec2f(sin((t * 3.7f)), cos((t * 4.3f))) * heatJitterNow));
  let field = (((noise(p) * 0.62f) + (noise(((p * 2.1f) + 5.3f)) * 0.26f)) + (noise(((p * 4.2f) + 1.7f)) * 0.12f));
  var heat = clamp((((field - (*u).p_lo) * heatGainNow) / max(((*u).p_hi - (*u).p_lo), 0.01f)), 0f, 1f);
  let gpix = floor((fragCoord / max((*u).p_grainSize, 1f)));
  let frame = floor(((*u).time * 48f));
  heat += ((grainNoise(gpix, frame, 3.1f) - 0.5f) * (*u).p_dither);
  let banded = (floor(((heat * (*u).p_bands) + 0.5f)) / (*u).p_bands);
  heat = clamp(mix(heat, banded, (*u).p_banding), 0f, 1f);
  heat = pow(heat, (*u).p_contrast);
  var base = mix((*u).c_cold, (*u).c_cool, smoothstep(0f, 0.3f, heat));
  base = mix(base, (*u).c_warm, smoothstep(0.3f, 0.55f, heat));
  base = mix(base, (*u).c_hot, smoothstep(0.55f, 0.78f, heat));
  base = mix(base, (*u).c_core, smoothstep(0.78f, 0.97f, heat));
  let soft = (*u).p_dotSoft;
  let mis = (*u).p_misregister;
  let cC = screen(orbUv, (0.035f * mis), (vec2f(0.2199999988079071, 0.11999999731779099) * mis), (1f - base.x), soft);
  let cM = screen(orbUv, (-0.03f * mis), (vec2f(-0.14000000059604645, 0.20000000298023224) * mis), (1f - base.y), soft);
  let cY = screen(orbUv, 0f, vec2f(), (1f - base.z), soft);
  var print = (*u).c_paper;
  print = (print * mix(vec3f(1), vec3f(0.05000000074505806, 0.6200000047683716, 0.9200000166893005), (cC * (*u).p_ink)));
  print = (print * mix(vec3f(1), vec3f(0.9200000166893005, 0.07999999821186066, 0.47999998927116394), (cM * (*u).p_ink)));
  print = (print * mix(vec3f(1), vec3f(0.9800000190734863, 0.8600000143051147, 0.019999999552965164), (cY * (*u).p_ink)));
  var col = mix(base, print, (*u).p_printMix);
  col = (col * (1f + ((grainNoise(gpix, frame, 27.9f) - 0.5f) * (*u).p_grain)));
  let lambert = clamp(dot(n, vec3f(-0.4511292278766632, 0.5513802170753479, 0.7017565965652466)), 0f, 1f);
  col = (col * (1f - ((*u).p_light * (1f - lambert))));
  let fres = pow((1f - z), 2.5f);
  col = (col + ((*u).c_paper * (((*u).p_rim * fres) * 0.5f)));
  let a = mask;
  return vec4f((max(col, vec3f()) * a), a);
}
