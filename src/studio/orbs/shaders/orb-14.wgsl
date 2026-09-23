// Compiled from unchanged shadercn orb-14 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: b5b3453c805219a95bec605108d46703a9152d01db8d284933d487c25b43c4a7
struct orb14Params {
  anim: f32,
  c_ink: vec3f,
  c_paper: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_cells: f32,
  p_contrast: f32,
  p_gain: f32,
  p_levels: f32,
  p_light: f32,
  p_plasma: f32,
  p_radius: f32,
  p_rim: f32,
  p_scale: f32,
  p_speed: f32,
  p_spin: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb14Params;

fn bayer2(a: vec2f) -> f32 {
  let f = floor(a);
  return fract(((f.x / 2f) + ((f.y * f.y) * 0.75f)));
}

fn bayer8(a: vec2f) -> f32 {
  return (((bayer2((a * 0.25f)) * 0.0625f) + (bayer2((a * 0.5f)) * 0.25f)) + bayer2(a));
}

struct orb14Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb14Fragment(_arg_0: orb14Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let plasmaAmt = ((*u).p_plasma * (1f + (0.4f * (*u).inputVol)));
  let gainNow = ((*u).p_gain * (0.85f + (0.5f * (*u).outputVol)));
  let cellPx = max((min((*u).res.x, (*u).res.y) / max((*u).p_cells, 8f)), 1f);
  let pix = floor((fragCoord / cellPx));
  let cellCentre = ((pix + 0.5f) * cellPx);
  let suv = (((cellCentre * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let puv = (suv / (*u).p_radius);
  let r2 = dot(puv, puv);
  let mask = (1f - step(1f, r2));
  let z = sqrt(max((1f - r2), 0f));
  let n = vec3f(puv.x, puv.y, z);
  let rot = (*u).p_spin;
  let cr = cos(rot);
  let sr = sin(rot);
  let sp = vec3f(((n.x * cr) - (n.z * sr)), n.y, ((n.x * sr) + (n.z * cr)));
  let t = (*u).p_speed;
  let f = (*u).p_scale;
  var v = ((sin((((sp.x * f) * 3.1f) + t)) + sin((((((sp.y * 0.85f) + (sp.z * 0.4f)) * f) * 3.6f) - (t * 1.3f)))) + sin((((((sp.x + sp.y) + sp.z) * f) * 2.2f) + (t * 0.7f))));
  let src = (vec2f(cos((t * 0.5f)), sin((t * 0.5f))) * 0.55f);
  v += sin((((length((puv - src)) * f) * 5f) - (t * 2.2f)));
  v *= 0.25f;
  let lambert = clamp(dot(n, vec3f(-0.4511292278766632, 0.5513802170753479, 0.7017565965652466)), 0f, 1f);
  let fres = pow((1f - z), 2f);
  var lum = (((0.5f + ((0.5f * v) * plasmaAmt)) * (0.3f + ((*u).p_light * lambert))) + ((*u).p_rim * fres));
  lum = pow(clamp((lum * gainNow), 0f, 1f), (*u).p_contrast);
  let steps = max(((*u).p_levels - 1f), 1f);
  let q = clamp((floor(((lum * steps) + bayer8(pix))) / steps), 0f, 1f);
  let col = mix((*u).c_ink, (*u).c_paper, q);
  let alpha = mask;
  return vec4f((col * alpha), alpha);
}
