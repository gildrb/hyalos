// Compiled from unchanged shadercn orb-22 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: ad0d3318edd98e70cbbf02f1c38b1725d10ab596f0fcfced200433e06ed3b979
struct orb22Params {
  anim: f32,
  c_tint: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_alphaGain: f32,
  p_camDist: f32,
  p_contrast: f32,
  p_edge: f32,
  p_edgeFade: f32,
  p_envCore: f32,
  p_envRadius: f32,
  p_exposure: f32,
  p_fill: f32,
  p_focal: f32,
  p_glow: f32,
  p_glowFew: f32,
  p_hueDepth: f32,
  p_hueStep: f32,
  p_hug: f32,
  p_saturation: f32,
  p_scatter: f32,
  p_speed: f32,
  p_stepClamp: f32,
  p_stepScale: f32,
  p_turb: f32,
  p_wander: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb22Params;

fn hash(p: vec2f) -> f32 {
  return fract((sin(dot(p, vec2f(127.0999984741211, 311.70001220703125))) * 43758.5453123f));
}

fn vectorsRender(fragCoord: vec2f, vectorsTurb: f32, vectorsGlow: f32) -> vec3f {
  let u = (&params);
  let animTime = (*u).p_speed;
  let wander = (*u).p_wander;
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let ro = vec3f(0f, 0f, (*u).p_camDist);
  let rd = normalize(vec3f(uv.x, uv.y, -((*u).p_focal)));
  let axis = normalize(sin((vec3f(0, 2, 4) + wander)));
  var acc = vec3f();
  var T = 1f;
  var z = max(((*u).p_camDist - ((*u).p_envRadius * 1.3f)), 0f);
  let zEnd = ((*u).p_camDist + ((*u).p_envRadius * 1.3f));
  for (var i = 0u; i < 70u; i += 1u) {
    let p = (ro + (rd * z));
    let rl = max(length(p), 1e-3f);
    let q = mix(p, ((p / rl) * (*u).p_envRadius), (*u).p_hug);
    let v = ((axis * dot(axis, q)) + cross(axis, q));
    var a = v;
    for (var i_1 = 0u; i_1 < 7u; i_1 += 1u) {
      let dj = (f32(i_1) + 3f);
      let wave = sin((ceil((a * dj)) - animTime));
      a = (a + ((vec3f(wave.y, wave.z, wave.x) * vectorsTurb) / dj));
    }
    var dens = (((*u).p_stepScale * length(sin((a * a)))) * sqrt(length((v * sin(vec3f(v.y, v.z, v.x))))));
    dens = max(dens, 1e-4f);
    var w = (vec3f(9f, (f32(i) * (*u).p_hueStep), (((z - (*u).p_camDist) + (*u).p_envRadius) * (*u).p_hueDepth)) / dens);
    w = min(w, (vec3f((*u).p_stepClamp) * vec3f(1, 2, 1)));
    w = (w * (20f / max((*u).p_stepClamp, 1f)));
    let few = max((*u).p_glowFew, 1e-3f);
    let vc = ceil((v * 2f));
    let hcell = hash((vc.xy + (vec2f(7.309999942779541, 3.1700000762939453) * vc.z)));
    let cyc = fract((hcell + (animTime * 0.05f)));
    let sel = (smoothstep((1f - few), (1f - (0.5f * few)), cyc) * smoothstep(1f, (1f - (0.5f * few)), cyc));
    w = (w + (vec3f(1, 0.9599999785423279, 0.8799999952316284) * ((min((0.08f / (dens * dens)), 500f) * sel) * vectorsGlow)));
    let env = smoothstep(((*u).p_envRadius * 1.12f), ((*u).p_envRadius * (*u).p_envCore), length(p));
    w = ((w + (*u).p_fill) * env);
    acc = (acc + (w * T));
    T *= exp((-(dot(w, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464))) * (*u).p_scatter));
    z += dens;
    if (((T < 4e-3f) || (z > zEnd))) {
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

struct orb22Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb22Fragment(_arg_0: orb22Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let vectorsTurb = ((*u).p_turb * (1f + (0.5f * (*u).inputVol)));
  let vectorsExposure = ((*u).p_exposure * (1f - (0.35f * (*u).outputVol)));
  let vectorsGlow = ((*u).p_glow * (1f + (0.8f * (*u).outputVol)));
  let acc = vectorsRender(fragCoord, vectorsTurb, vectorsGlow);
  var col = tanh3((acc / max(vectorsExposure, 1f)));
  col = pow(clamp(col, vec3f(), vec3f(1)), vec3f((*u).p_contrast));
  let lum = dot(col, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464));
  col = mix(vec3f(lum), col, (*u).p_saturation);
  col = (col * (*u).c_tint);
  let peak = max(col.x, max(col.y, col.z));
  var a = clamp((peak * (*u).p_alphaGain), 0f, 1f);
  let mrd = normalize(vec3f(orbUv.x, orbUv.y, -((*u).p_focal)));
  let closest = length(cross(vec3f(0f, 0f, (*u).p_camDist), mrd));
  let band = mix(0.35f, 0.012f, clamp((*u).p_edge, 0f, 1f));
  let mask = (1f - smoothstep(((*u).p_envRadius * (1f - band)), ((*u).p_envRadius * 1.005f), closest));
  col = (col * mask);
  a *= mask;
  let r2d = length(orbUv);
  let fade = (1f - smoothstep((*u).p_edgeFade, 1f, r2d));
  col = (col * fade);
  a *= fade;
  return vec4f(col, a);
}
