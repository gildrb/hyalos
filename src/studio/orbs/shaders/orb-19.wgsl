// Compiled from unchanged shadercn orb-19 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 3de8d47b7d050318d03c167d233591c6e3074dde1fa0add4ecf948756d4cb4ba
struct orb19Params {
  anim: f32,
  c_body: vec3f,
  c_high: vec3f,
  c_low: vec3f,
  c_sheen: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_bead: f32,
  p_bulge: f32,
  p_contrast: f32,
  p_edge: f32,
  p_floorLevel: f32,
  p_gain: f32,
  p_grow: f32,
  p_jitter: f32,
  p_light: f32,
  p_radius: f32,
  p_rim: f32,
  p_saturation: f32,
  p_scale: f32,
  p_skew: f32,
  p_slide: f32,
  p_speed: f32,
  p_swirl: f32,
  p_vary: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb19Params;

fn rot2(angle: f32) -> mat2x2f {
  let c = cos(angle);
  let s = sin(angle);
  return mat2x2f(vec2f(c, -(s)), vec2f(s, c));
}

fn hash(p: vec2f) -> f32 {
  return fract((sin(dot(p, vec2f(127.0999984741211, 311.70001220703125))) * 43758.5453123f));
}

fn foamRender(fragCoord: vec2f, foamGrow: f32, foamJitter: f32, foamGain: f32) -> vec3f {
  let u = (&params);
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let R = max((*u).p_radius, 1e-3f);
  let pl = (uv / R);
  let z = sqrt(max((1f - dot(pl, pl)), 0f));
  let t = (*u).p_speed;
  var p = ((pl / ((z + 1f) + (*u).p_bulge)) * (*u).p_scale);
  let sw = (*u).p_swirl;
  p = (rot2(sw) * p);
  p = (p + vec2f((*u).p_slide, ((*u).p_slide * 0.7f)));
  let cell = ceil(p);
  let f = (p - cell);
  var cover = 0f;
  var bestRel = 1e+9f;
  var bestDelta = vec2f();
  var bestRad = 1f;
  var bestId = vec2f();
  for (var i = 0u; i < 3u; i += 1u) {
    for (var i_1 = 0u; i_1 < 3u; i_1 += 1u) {
      let g = vec2f((f32(i_1) - 1f), (f32(i) - 1f));
      let id = (cell + g);
      let rad = ((dot(cos((id - t)), sin(((id.yx * (*u).p_skew) + t))) * (*u).p_vary) + foamGrow);
      let jit = (cos((id.yx + t)) * foamJitter);
      let delta = ((f - g) - jit);
      let dist = length(delta);
      cover = max(cover, clamp(((rad - dist) * (*u).p_edge), 0f, 1f));
      let rel = (dist / max(rad, 1e-4f));
      if ((rel < bestRel)) {
        bestRel = rel;
        bestDelta = delta;
        bestRad = rad;
        bestId = id;
      }
    }
  }
  let rr = max(bestRad, 1e-4f);
  let dome = clamp((1f - (dot(bestDelta, bestDelta) / (rr * rr))), 0f, 1f);
  let bn = normalize(vec3f((bestDelta / rr), (sqrt(dome) + 1e-3f)));
  let key = vec3f(-0.4448256194591522, 0.5436757802963257, 0.7117210030555725);
  let beadLam = clamp(dot(bn, key), 0f, 1f);
  let beadCol = mix((*u).c_low, (*u).c_high, hash((bestId + 0.5f)));
  let shade = mix(1f, (0.45f + (0.85f * beadLam)), (*u).p_bead);
  var col = (beadCol * ((shade * foamGain) * cover));
  col = (col + ((*u).c_body * (*u).p_floorLevel));
  col = pow(max(col, vec3f()), vec3f((*u).p_contrast));
  let lum = dot(col, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464));
  col = mix(vec3f(lum), col, (*u).p_saturation);
  let n = vec3f(pl, z);
  let lambert = clamp(dot(n, key), 0f, 1f);
  col = (col * (0.55f + ((*u).p_light * lambert)));
  let fres = (1f - z);
  let fresCubed = ((fres * fres) * fres);
  col = (col + ((*u).c_sheen * ((*u).p_rim * fresCubed)));
  return col;
}

struct orb19Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb19Fragment(_arg_0: orb19Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let foamGrow = ((*u).p_grow * (1f + (0.35f * (*u).outputVol)));
  let foamJitter = ((*u).p_jitter * (1f + (0.5f * (*u).inputVol)));
  let foamGain = ((*u).p_gain * (0.85f + (0.4f * (*u).outputVol)));
  let mask = smoothstep(0.012f, -0.012f, (length(orbUv) - max((*u).p_radius, 1e-3f)));
  if ((mask <= 0f)) {
    return vec4f();
  }
  let col = foamRender(fragCoord, foamGrow, foamJitter, foamGain);
  let a = mask;
  return vec4f((max(col, vec3f()) * a), a);
}
