// Compiled from unchanged shadercn orb-29 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: d8f2c300f95e7b8998909d2da5b789ee61ad583c7b7ea70132e925698e7f0ffd
struct orb29Params {
  anim: f32,
  c_lit: vec3f,
  c_wall: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_cells: f32,
  p_churn: f32,
  p_confetti: f32,
  p_contrast: f32,
  p_coverage: f32,
  p_drift: f32,
  p_gain: f32,
  p_light: f32,
  p_pulse: f32,
  p_radius: f32,
  p_scale: f32,
  p_shuffle: f32,
  p_spin: f32,
  p_swirl: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb29Params;

fn hash(p: vec2f) -> f32 {
  return fract((sin(dot(p, vec2f(127.0999984741211, 311.70001220703125))) * 43758.5453123f));
}

fn noise(p: vec2f) -> f32 {
  let i = floor(p);
  let f = fract(p);
  let ff = ((f * f) * (vec2f(3) - (f * 2f)));
  return mix(mix(hash(i), hash((i + vec2f(1, 0))), ff.x), mix(hash((i + vec2f(0, 1))), hash((i + vec2f(1))), ff.x), ff.y);
}

fn fbm(pIn: vec2f) -> f32 {
  var p = pIn;
  var v = 0f;
  var a = 0.5f;
  for (var i = 0u; i < 5u; i += 1u) {
    v += (a * noise(p));
    p = ((p * 2.03f) + vec2f(11.699999809265137, 7.300000190734863));
    a *= 0.5f;
  }
  return v;
}

struct orb29Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb29Fragment(_arg_0: orb29Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let coverNow = ((*u).p_coverage + (0.07f * (*u).inputVol));
  let gainNow = ((*u).p_gain * (0.85f + (0.5f * (*u).outputVol)));
  let cellPx = max((min((*u).res.x, (*u).res.y) / max((*u).p_cells, 8f)), 4f);
  let cellIdx = floor((fragCoord / cellPx));
  let cellCentre = ((cellIdx + 0.5f) * cellPx);
  let g = fract((fragCoord / cellPx));
  let suv = (((cellCentre * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let duv = (suv / (*u).p_radius);
  let r2 = dot(duv, duv);
  let mask = (1f - step(1f, r2));
  let z = sqrt(max((1f - r2), 0f));
  let n = vec3f(duv, z);
  let rot = (*u).p_spin;
  let cr = cos(rot);
  let sr = sin(rot);
  let sp = vec3f(((n.x * cr) - (n.z * sr)), n.y, ((n.x * sr) + (n.z * cr)));
  let p2 = ((sp.xy / (abs(sp.z) + 1.2f)) * ((*u).p_scale * 3f));
  let driftT = (*u).p_drift;
  let churnT = (*u).p_churn;
  let shuffleT = (*u).p_shuffle;
  let f1 = vec2f((driftT * 0.5f), (-(driftT) * 0.35f));
  let f2 = vec2f((-(churnT) * 0.4f), (churnT * 0.6f));
  let warp = (vec2f(fbm(((p2 * 0.9f) + f2)), fbm((((p2 * 0.9f) + f2.yx) + 13.7f))) - 0.5f);
  let field = fbm(((p2 + f1) + (warp * ((*u).p_swirl * 2.4f))));
  let lambert = clamp(dot(n, vec3f(-0.4511292278766632, 0.5513802170753479, 0.7017565965652466)), 0f, 1f);
  var lum = smoothstep((1f - coverNow), (1.14f - coverNow), ((field + ((0.25f * (*u).p_light) * lambert)) + (((*u).p_pulse * 0.3f) * sin(((length(duv) * 5f) - (driftT * 3.2f))))));
  lum *= gainNow;
  let d2 = abs((g - 0.5f));
  let md = max(d2.x, d2.y);
  let face = (1f - smoothstep(0.26f, 0.36f, md));
  let tile = (1f - smoothstep(0.42f, 0.48f, md));
  let hot = (1f - smoothstep(0f, 0.34f, length(d2)));
  let h1 = hash(((cellIdx * 1.618f) + 7.3f));
  let h2 = hash(((cellIdx * 2.113f) + 41.7f));
  let cyc = fract((h1 + (shuffleT * 0.06f)));
  let promoted = step((1f - (*u).p_confetti), cyc);
  var confetti = (vec3f(0.5) + (cos(((vec3f(h2) + vec3f(0, 0.33000001311302185, 0.6700000166893005)) * 6.2831f)) * 0.5f));
  confetti = (normalize((confetti + 0.05f)) * 1.2f);
  let litCol = mix((*u).c_lit, confetti, promoted);
  let offCol = ((*u).c_wall * tile);
  let onCol = ((litCol * ((face * 1.05f) + (hot * 0.5f))) * lum);
  var col = (offCol + onCol);
  col = pow(max(col, vec3f()), vec3f((*u).p_contrast));
  let a = mask;
  return vec4f((col * a), a);
}
