// Compiled from unchanged shadercn orb-13 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 9d5bde31ad0ee85e852fd18e3cd62b3b4139dbc20bc5bd617c5d1bbf200da1af
struct orb13Params {
  anim: f32,
  c_arc: vec3f,
  c_inner: vec3f,
  c_tint: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_alphaGain: f32,
  p_camDist: f32,
  p_contrast: f32,
  p_coreGain: f32,
  p_edge: f32,
  p_envRadius: f32,
  p_exposure: f32,
  p_fill: f32,
  p_fils: f32,
  p_focal: f32,
  p_saturation: f32,
  p_scatter: f32,
  p_sharp: f32,
  p_soft: f32,
  p_speed: f32,
  p_spin: f32,
  p_stepClamp: f32,
  p_swell: f32,
  p_tilt: f32,
  p_tipGain: f32,
  p_whiten: f32,
  p_writhe: f32,
  p_writheFreq: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb13Params;

fn hash(p: vec2f) -> f32 {
  return fract((sin(dot(p, vec2f(127.0999984741211, 311.70001220703125))) * 43758.5453123f));
}

fn rot2(angle: f32) -> mat2x2f {
  let c = cos(angle);
  let s = sin(angle);
  return mat2x2f(vec2f(c, -(s)), vec2f(s, c));
}

fn ionRender(fragCoord: vec2f, ionSharp: f32, ionWrithe: f32, ionCore: f32, ionRadius: f32) -> vec3f {
  let u = (&params);
  let t = (*u).p_speed;
  let spinAng = (*u).p_spin;
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let ro = vec3f(0f, 0f, (*u).p_camDist);
  let rd = normalize(vec3f(uv.x, uv.y, -((*u).p_focal)));
  let proj = dot((ro * -1f), rd);
  let b2 = (dot(ro, ro) - (proj * proj));
  let halfChord = sqrt(max(((ionRadius * ionRadius) - b2), 0f));
  var zNear = (proj - halfChord);
  let stepLen = ((2f * halfChord) / 64f);
  zNear += ((hash(fragCoord) - 0.5f) * stepLen);
  var acc = vec3f();
  var T = 1f;
  for (var i = 0u; i < 64u; i += 1u) {
    let p = (ro + (rd * (zNear + ((f32(i) + 0.5f) * stepLen))));
    var pr = p;
    let prSpun = (rot2(spinAng) * vec2f(pr.x, pr.z));
    pr = vec3f(prSpun.x, pr.y, prSpun.y);
    let prTilt = (rot2((*u).p_tilt) * vec2f(pr.y, pr.z));
    pr = vec3f(pr.x, prTilt.x, prTilt.y);
    let rad = length(pr);
    let dir = (pr / max(rad, 1e-4f));
    let rr = (rad / max(ionRadius, 1e-3f));
    let wr = (ionWrithe * smoothstep(0f, (ionRadius * 0.35f), rad));
    var q = (dir * (*u).p_fils);
    q = (q + (vec3f(sin((((rad * (*u).p_writheFreq) - (t * 1.2f)) + (q.y * 1.8f))), sin(((((rad * (*u).p_writheFreq) * 0.83f) + (t * 1f)) + (q.z * 1.8f))), sin(((((rad * (*u).p_writheFreq) * 1.19f) - (t * 0.7f)) + (q.x * 1.8f)))) * wr));
    let f1 = ((sin((q.x + (t * 0.7f))) + sin(((q.y * 1.31f) - (t * 0.5f)))) + sin(((q.z * 1.13f) + (t * 0.9f))));
    let f2 = ((sin((((q.y * 1.21f) + (t * 0.6f)) + 1.7f)) + sin((((q.z * 1.43f) - (t * 0.8f)) + 3.1f))) + sin((((q.x * 0.87f) + (t * 0.4f)) + 5f)));
    let d2 = ((f1 * f1) + (f2 * f2));
    var g = (1f / ((d2 * ionSharp) + (*u).p_soft));
    g *= (1f + ((*u).p_tipGain * smoothstep(0.55f, 0.95f, rr)));
    let core = (ionCore / (((rad * rad) * 8f) + 0.05f));
    let fCol = mix((*u).c_inner, (*u).c_arc, smoothstep(0.1f, 0.75f, rr));
    var w = ((((fCol + (vec3f((*u).p_whiten) * g)) * g) + ((*u).c_inner * core)) + vec3f((*u).p_fill));
    w = min(w, vec3f((*u).p_stepClamp));
    w = (w * stepLen);
    acc = (acc + (w * T));
    T *= exp((-(dot(w, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464))) * (*u).p_scatter));
    if ((T < 4e-3f)) {
      break;
    }
  }
  return acc;
}

fn tanh3(x: vec3f) -> vec3f {
  let clamped = clamp(x, vec3f(-10), vec3f(10));
  let e = exp((clamped * 2f));
  return ((e - 1f) / (e + 1f));
}

struct orb13Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb13Fragment(_arg_0: orb13Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let ionSharp = ((*u).p_sharp * (1f - (0.25f * (*u).outputVol)));
  let ionWrithe = ((*u).p_writhe * (1f + (0.6f * (*u).outputVol)));
  let ionCore = ((*u).p_coreGain * ((1f + (1.6f * (*u).inputVol)) + (0.4f * (*u).outputVol)));
  let ionExposure = ((*u).p_exposure * (1f - (0.35f * (*u).outputVol)));
  let ionRadius = ((*u).p_envRadius + ((*u).p_swell * (*u).inputVol));
  let acc = ionRender(fragCoord, ionSharp, ionWrithe, ionCore, ionRadius);
  var col = tanh3((acc / max(ionExposure, 0.01f)));
  col = pow(clamp(col, vec3f(), vec3f(1)), vec3f((*u).p_contrast));
  let lum = dot(col, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464));
  col = (mix(vec3f(lum), col, (*u).p_saturation) * (*u).c_tint);
  let peak = max(col.x, max(col.y, col.z));
  var alpha = clamp((peak * (*u).p_alphaGain), 0f, 1f);
  let mrd = normalize(vec3f(orbUv.x, orbUv.y, -((*u).p_focal)));
  let closest = length(cross(vec3f(0f, 0f, (*u).p_camDist), mrd));
  let band = mix(0.35f, 0.012f, clamp((*u).p_edge, 0f, 1f));
  let mask = (1f - smoothstep((ionRadius * (1f - band)), (ionRadius * 1.005f), closest));
  col = (col * mask);
  alpha *= mask;
  return vec4f(col, alpha);
}
