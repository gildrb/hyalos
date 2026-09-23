// Compiled from unchanged shadercn orb-27 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 0af691400ff9a8c5f45868e6ca0a98469a32cdb22b29b8072f8f1ef71622f9bd
struct orb27Params {
  anim: f32,
  c_c0: vec3f,
  c_c1: vec3f,
  c_c2: vec3f,
  c_c3: vec3f,
  c_c4: vec3f,
  c_c5: vec3f,
  c_c6: vec3f,
  c_paper: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_cells: f32,
  p_curve: f32,
  p_density: f32,
  p_dither: f32,
  p_dot: f32,
  p_freq: f32,
  p_grain: f32,
  p_hi: f32,
  p_light: f32,
  p_lo: f32,
  p_radius: f32,
  p_rim: f32,
  p_scale: f32,
  p_sparse: f32,
  p_speed: f32,
  p_spin: f32,
  p_swirl: f32,
  p_twinkle: f32,
  p_vortex: f32,
  p_warp: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb27Params;

fn hash(p: vec2f) -> f32 {
  return fract((sin(dot(p, vec2f(127.0999984741211, 311.70001220703125))) * 43758.5453123f));
}

fn rotateAbout(v: vec3f, k: vec3f, a: f32) -> vec3f {
  let c = cos(a);
  let s = sin(a);
  return (((v * c) + (cross(k, v) * s)) + (k * (dot(k, v) * (1f - c))));
}

fn hash3(p: vec3f) -> f32 {
  return fract((sin(dot(p, vec3f(127.0999984741211, 311.70001220703125, 74.69999694824219))) * 43758.5453123f));
}

fn noise3(p: vec3f) -> f32 {
  let i = floor(p);
  var f = fract(p);
  f = ((f * f) * (vec3f(3) - (f * 2f)));
  let n000 = hash3(i);
  let n100 = hash3((i + vec3f(1, 0, 0)));
  let n010 = hash3((i + vec3f(0, 1, 0)));
  let n110 = hash3((i + vec3f(1, 1, 0)));
  let n001 = hash3((i + vec3f(0, 0, 1)));
  let n101 = hash3((i + vec3f(1, 0, 1)));
  let n011 = hash3((i + vec3f(0, 1, 1)));
  let n111 = hash3((i + vec3f(1)));
  return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y), mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

fn fbm3(p: vec3f) -> f32 {
  var q = p;
  var v = 0f;
  var a = 0.5f;
  for (var i = 0u; i < 4u; i += 1u) {
    v += (a * noise3(q));
    q = ((q * 2.03f) + vec3f(11.699999809265137, 7.300000190734863, 3.0999999046325684));
    a *= 0.5f;
  }
  return v;
}

fn intensity(sp: vec3f, t: f32, radarLoNow: f32) -> f32 {
  let u = (&params);
  var q = sp;
  for (var i = 0u; i < 6u; i += 1u) {
    let fk = f32(i);
    var c = normalize(vec3f((hash(vec2f((fk * 3.7f), 1.1f)) - 0.5f), (hash(vec2f((fk * 5.9f), 2.3f)) - 0.5f), (hash(vec2f((fk * 7.1f), 4.9f)) - 0.5f)));
    c = rotateAbout(c, vec3f(0, 1, 0), (sin(((t * 0.09f) + (fk * 1.7f))) * 0.25f));
    let ang = acos(clamp(dot(q, c), -1f, 1f));
    let fall = exp(((-(ang) * ang) / ((*u).p_vortex * (*u).p_vortex)));
    let a = (((*u).p_swirl * fall) * f32(select(-1i, 1i, ((fk % 2f) < 0.5f))));
    q = rotateAbout(q, c, a);
  }
  let w = (vec3f(noise3(((q * 1.3f) + 2.1f)), noise3(((q * 1.3f) + 7.3f)), noise3(((q * 1.3f) + 4.4f))) - 0.5f);
  q = (q + (w * (*u).p_warp));
  let pq = ((q * (*u).p_freq) + vec3f((t * 0.22f), (-(t) * 0.13f), (t * 0.07f)));
  let big = clamp((((fbm3(pq) - 0.5f) * 3f) + 0.5f), 0f, 1f);
  let fine = clamp((((fbm3(((pq * 2.6f) + 4.7f)) - 0.5f) * 2.4f) + 0.5f), 0f, 1f);
  var f = (big * (0.55f + (0.45f * fine)));
  f = clamp(((f - radarLoNow) / max(((*u).p_hi - radarLoNow), 0.01f)), 0f, 1f);
  return pow(f, (*u).p_curve);
}

struct orb27Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb27Fragment(_arg_0: orb27Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let radarLoNow = ((*u).p_lo - (0.08f * (*u).inputVol));
  let radarDensityNow = ((*u).p_density * (1f + (0.5f * (*u).outputVol)));
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
  let t = (*u).p_speed;
  let st = ((n.xy / (1.3f + n.z)) * (*u).p_scale);
  let g = (st * (*u).p_cells);
  let cell = floor(g);
  let fr = (fract(g) - 0.5f);
  let v = (((cell + 0.5f) / (*u).p_cells) / (*u).p_scale);
  let vv = dot(v, v);
  let A = (vv + 1f);
  let B = (2.6f * vv);
  let C = ((1.69f * vv) - 1f);
  let zc = ((-(B) + sqrt(max(((B * B) - ((4f * A) * C)), 0f))) / (2f * A));
  let nc = vec3f((v * (1.3f + zc)), zc);
  let cr = cos((*u).p_spin);
  let sr = sin((*u).p_spin);
  let spc = vec3f(((nc.x * cr) - (nc.z * sr)), nc.y, ((nc.x * sr) + (nc.z * cr)));
  let f = intensity(spc, t, radarLoNow);
  let h = hash((cell + 11.7f));
  let fd = clamp((f + ((h - 0.5f) * (*u).p_dither)), 0f, 1f);
  var cls = 0f;
  cls += step(0.1f, fd);
  cls += step(0.26f, fd);
  cls += step(0.38f, fd);
  cls += step(0.46f, fd);
  cls += step(0.78f, fd);
  cls += step(0.94f, fd);
  let frame = floor(((*u).time * (*u).p_twinkle));
  let roll = hash((cell + vec2f((frame * 3.7f), (-(frame) * 1.3f))));
  let density = (mix((*u).p_sparse, 1f, smoothstep(0f, 0.6f, f)) * radarDensityNow);
  let keep = step(roll, density);
  let dsq = max(abs(fr.x), abs(fr.y));
  let dotMask = (1f - smoothstep(((*u).p_dot - 0.06f), ((*u).p_dot + 0.06f), dsq));
  var ink = (*u).c_c0;
  ink = select(ink, (*u).c_c1, ((cls > 0.5f) && (cls < 1.5f)));
  ink = select(ink, (*u).c_c2, ((cls > 1.5f) && (cls < 2.5f)));
  ink = select(ink, (*u).c_c3, ((cls > 2.5f) && (cls < 3.5f)));
  ink = select(ink, (*u).c_c4, ((cls > 3.5f) && (cls < 4.5f)));
  ink = select(ink, (*u).c_c5, ((cls > 4.5f) && (cls < 5.5f)));
  ink = select(ink, (*u).c_c6, (cls > 5.5f));
  var col = mix((*u).c_paper, ink, (dotMask * keep));
  col = (col * (1f + ((hash((floor((fragCoord / 2f)) + frame)) - 0.5f) * (*u).p_grain)));
  let lambert = clamp(dot(n, vec3f(-0.4511292278766632, 0.5513802170753479, 0.7017565965652466)), 0f, 1f);
  col = (col * (1f - ((*u).p_light * (1f - lambert))));
  let fres = pow((1f - z), 3f);
  col = mix(col, (*u).c_c0, (fres * (*u).p_rim));
  let a = mask;
  return vec4f((max(col, vec3f()) * a), a);
}
