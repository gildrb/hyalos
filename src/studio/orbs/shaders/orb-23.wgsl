// Compiled from unchanged shadercn orb-23 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: c6c77dbbcefddeab5de1fba37e35ec4e991ea2f2e019ce0bf333a9f6b76facc4
struct orb23Params {
  anim: f32,
  c_deep: vec3f,
  c_glow: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_cells: f32,
  p_contrast: f32,
  p_density: f32,
  p_drift: f32,
  p_dropout: f32,
  p_gain: f32,
  p_light: f32,
  p_pulse: f32,
  p_radius: f32,
  p_rim: f32,
  p_scale: f32,
  p_scroll: f32,
  p_speed: f32,
  p_spin: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb23Params;

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

struct orb23Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb23Fragment(_arg_0: orb23Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let densBias = ((*u).p_density + (0.2f * (*u).inputVol));
  let gainNow = ((*u).p_gain * (0.85f + (0.5f * (*u).outputVol)));
  let cellPx = max((min((*u).res.x, (*u).res.y) / max((*u).p_cells, 8f)), 4f);
  let cellIdx = floor((fragCoord / cellPx));
  let cellCentre = ((cellIdx + 0.5f) * cellPx);
  let g = fract((fragCoord / cellPx));
  let suv = (((cellCentre * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let nuv = (suv / (*u).p_radius);
  let r2 = dot(nuv, nuv);
  let mask = (1f - step(1f, r2));
  let z = sqrt(max((1f - r2), 0f));
  let n = vec3f(nuv.x, nuv.y, z);
  let rot = (*u).p_spin;
  let cr = cos(rot);
  let sr = sin(rot);
  let sp = vec3f(((n.x * cr) - (n.z * sr)), n.y, ((n.x * sr) + (n.z * cr)));
  let p2 = ((sp.xy / (abs(sp.z) + 1.2f)) * ((*u).p_scale * 3f));
  let driftT = (*u).p_drift;
  let scrollT = (*u).p_scroll;
  let t = (*u).p_speed;
  let flow = vec2f((driftT * 0.6f), ((-(driftT) * 0.45f) - scrollT));
  let field = fbm((p2 + flow));
  let lambert = clamp(dot(n, vec3f(-0.4511292278766632, 0.5513802170753479, 0.7017565965652466)), 0f, 1f);
  let dens = clamp((((((field - 0.5f) * 1.8f) + densBias) + ((0.4f * (*u).p_light) * lambert)) + (((*u).p_pulse * 0.35f) * sin(((length(nuv) * 5.5f) - (t * 2.4f))))), 0f, 1f);
  let rowI = floor((g.y * 4f));
  let bar = (step(0.22f, fract((g.y * 4f))) * step(fract((g.y * 4f)), 0.9f));
  let stripe = step(0.18f, fract((g.x * 3f)));
  let lit = step((rowI + 0.5f), ((dens * 4f) * gainNow));
  var glyph = ((bar * stripe) * lit);
  let superCentre = (((floor((cellIdx / 2f)) * 2f) + 1f) * cellPx);
  let sSuv = (((superCentre * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let sUv2 = (sSuv / (*u).p_radius);
  let sz = sqrt(max((1f - dot(sUv2, sUv2)), 0f));
  let ssp = vec3f(((sUv2.x * cr) - (sz * sr)), sUv2.y, ((sUv2.x * sr) + (sz * cr)));
  let superField = fbm((((ssp.xy / (abs(ssp.z) + 1.2f)) * ((*u).p_scale * 3f)) + flow));
  let keep = step((*u).p_dropout, (superField + (0.15f * (*u).outputVol)));
  glyph *= keep;
  var glyphCol = mix((*u).c_deep, (*u).c_glow, dens);
  glyphCol = (glyphCol + (vec3f(0.699999988079071, 1, 0.8999999761581421) * (pow(dens, 3f) * 0.35f)));
  let fres = pow((1f - z), 2.2f);
  var col = ((((*u).c_deep * 0.22f) + (glyphCol * glyph)) + ((*u).c_glow * (fres * (*u).p_rim)));
  col = pow(max(col, vec3f()), vec3f((*u).p_contrast));
  let a = mask;
  return vec4f((col * a), a);
}
