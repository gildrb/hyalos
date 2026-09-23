// Compiled from unchanged shadercn orb-07 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 372b2c412fd9bd5246cea73683bfecd130077fdf1a4188c27f2b8da0bbf25921
struct orb07Params {
  anim: f32,
  c_tint: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_alphaGain: f32,
  p_camDist: f32,
  p_column: f32,
  p_contrast: f32,
  p_edge: f32,
  p_edgeFade: f32,
  p_envCore: f32,
  p_envRadius: f32,
  p_exposure: f32,
  p_fill: f32,
  p_focal: f32,
  p_hueDepth: f32,
  p_hueStep: f32,
  p_saturation: f32,
  p_scatter: f32,
  p_speed: f32,
  p_spin: f32,
  p_stepClamp: f32,
  p_stepScale: f32,
  p_tilt: f32,
  p_turb: f32,
  p_twist: f32,
  p_wave: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb07Params;

fn roundv(x: vec3f) -> vec3f {
  return floor((x + 0.5f));
}

fn torsionRender(fragCoord: vec2f, torsionTurb: f32, torsionTwist: f32) -> vec3f {
  let u = (&params);
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let ro = vec3f(0f, 0f, (*u).p_camDist);
  let rd = normalize(vec3f(uv.x, uv.y, -((*u).p_focal)));
  let shimmer = (*u).p_speed;
  let wave = (*u).p_wave;
  let spin = (*u).p_spin;
  let ct = cos((*u).p_tilt);
  let st = sin((*u).p_tilt);
  let cs = cos(spin);
  let ss = sin(spin);
  let axis = vec3f(0, 1, 0);
  var acc = vec3f();
  var T = 1f;
  var z = max(((*u).p_camDist - ((*u).p_envRadius * 1.3f)), 0f);
  let zEnd = ((*u).p_camDist + ((*u).p_envRadius * 1.3f));
  for (var i = 0u; i < 50u; i += 1u) {
    let world = (ro + (rd * z));
    var p = vec3f(world.x, ((world.y * ct) + (world.z * st)), ((-(world.y) * st) + (world.z * ct)));
    p = vec3f(((p.x * cs) - (p.z * ss)), p.y, ((p.x * ss) + (p.z * cs)));
    let h = ((length(p) * torsionTwist) - wave);
    var a = (mix((axis * dot(axis, p)), p, sin(h)) + (cross(axis, p) * cos(h)));
    for (var i_1 = 0u; i_1 < 9u; i_1 += 1u) {
      let dj = (f32(i_1) + 1f);
      a = (a + ((sin((roundv((a * dj)) - shimmer)).zxy * torsionTurb) / dj));
    }
    var dist = ((*u).p_stepScale * mix(length(a.xz), length(a), (*u).p_column));
    dist = max(dist, ((*u).p_envRadius * 3e-3f));
    var w = (vec3f(3f, (((z - (*u).p_camDist) + (*u).p_envRadius) * (*u).p_hueDepth), (f32(i) * (*u).p_hueStep)) / dist);
    w = min(w, (vec3f((*u).p_stepClamp) * vec3f(1, 1, 2)));
    w = (w * (20f / max((*u).p_stepClamp, 1f)));
    let env = smoothstep(((*u).p_envRadius * 1.12f), ((*u).p_envRadius * (*u).p_envCore), length(world));
    w = ((w + (*u).p_fill) * env);
    acc = (acc + (w * T));
    T *= exp((-(dot(w, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464))) * (*u).p_scatter));
    z += dist;
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

struct orb07Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb07Fragment(_arg_0: orb07Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let torsionTurb = ((*u).p_turb * (1f + (0.5f * (*u).inputVol)));
  let torsionExposure = ((*u).p_exposure * (1f - (0.35f * (*u).outputVol)));
  let torsionTwist = ((*u).p_twist * (1f + (0.4f * (*u).outputVol)));
  let acc = torsionRender(fragCoord, torsionTurb, torsionTwist);
  var col = tanh3((acc / max(torsionExposure, 1f)));
  col = pow(clamp(col, vec3f(), vec3f(1)), vec3f((*u).p_contrast));
  let lum = dot(col, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464));
  col = (mix(vec3f(lum), col, (*u).p_saturation) * (*u).c_tint);
  let peak = max(col.x, max(col.y, col.z));
  var alpha = clamp((peak * (*u).p_alphaGain), 0f, 1f);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let mrd = normalize(vec3f(orbUv.x, orbUv.y, -((*u).p_focal)));
  let closest = length(cross(vec3f(0f, 0f, (*u).p_camDist), mrd));
  let band = mix(0.35f, 0.012f, clamp((*u).p_edge, 0f, 1f));
  let mask = (1f - smoothstep(((*u).p_envRadius * (1f - band)), ((*u).p_envRadius * 1.005f), closest));
  col = (col * mask);
  alpha *= mask;
  let fade = (1f - smoothstep((*u).p_edgeFade, 1f, length(orbUv)));
  col = (col * fade);
  alpha *= fade;
  return vec4f(col, alpha);
}
