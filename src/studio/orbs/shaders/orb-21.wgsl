// Compiled from unchanged shadercn orb-21 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: c82134bc069440e6035f751c2206255a51d304b00bc9ffadbb4183b693d95249
struct orb21Params {
  anim: f32,
  c_light: vec3f,
  c_shadow: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_absorb: f32,
  p_alphaGain: f32,
  p_ambient: f32,
  p_aniso: f32,
  p_camDist: f32,
  p_churn: f32,
  p_density: f32,
  p_edgeSoft: f32,
  p_exposure: f32,
  p_focal: f32,
  p_lightSpin: f32,
  p_power: f32,
  p_radius: f32,
  p_scale: f32,
  p_shadowAbsorb: f32,
  p_shadowLift: f32,
  p_speed: f32,
  p_threshold: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb21Params;

fn phaseHG(c: f32, g: f32) -> f32 {
  let g2 = (g * g);
  return ((1f - g2) / pow(max(((1f + g2) - ((2f * g) * c)), 1e-4f), 1.5f));
}

fn density(p: vec3f, animTime: f32, nimbusDensity: f32) -> f32 {
  let u = (&params);
  let shell = (1f - (length(p) / (*u).p_radius));
  if ((shell <= 0f)) {
    return 0f;
  }
  var q = (p * (*u).p_scale);
  var f = 1f;
  for (var i = 0u; i < 4u; i += 1u) {
    q = (q + (cos(((vec3f(q.y, q.z, q.x) * f) + (animTime * (*u).p_churn))) / f));
    f *= 1.8f;
  }
  let n = (((((sin(q.x) + sin(q.y)) + sin(q.z)) / 3f) * 0.5f) + 0.5f);
  let clump = smoothstep((*u).p_threshold, 1f, n);
  return ((clump * pow(shell, (*u).p_edgeSoft)) * nimbusDensity);
}

fn nimbusRender(fragCoord: vec2f, nimbusPower: f32, nimbusDensity: f32) -> vec4f {
  let u = (&params);
  let animTime = (*u).p_speed;
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let ro = vec3f(0f, 0f, -((*u).p_camDist));
  let rd = normalize(vec3f(uv.x, uv.y, (*u).p_focal));
  let L = normalize(vec3f((cos((animTime * (*u).p_lightSpin)) * 0.7f), 0.45f, ((sin((animTime * (*u).p_lightSpin)) * 0.35f) + 0.65f)));
  let phase = phaseHG(dot(rd, L), (*u).p_aniso);
  let toCentre = (*u).p_camDist;
  let tStart = max((toCentre - (*u).p_radius), 0f);
  let span = (2f * (*u).p_radius);
  let dt = (span / 56f);
  var T = 1f;
  var scattered = vec3f();
  for (var i = 0u; i < 56u; i += 1u) {
    let t = (tStart + ((f32(i) + 0.5f) * dt));
    let p = (ro + (rd * t));
    let dn = density(p, animTime, nimbusDensity);
    if ((dn > 1e-3f)) {
      var shadow = 1f;
      let lstep = ((*u).p_radius / 4f);
      for (var i_1 = 0u; i_1 < 4u; i_1 += 1u) {
        let fk = (f32(i_1) + 1f);
        let lp = (p + (L * ((fk - 0.5f) * lstep)));
        shadow *= exp(((-(density(lp, animTime, nimbusDensity)) * lstep) * (*u).p_shadowAbsorb));
      }
      let lit = mix(((*u).c_shadow * (*u).p_shadowLift), (*u).c_light, shadow);
      scattered = (scattered + (lit * ((((T * dn) * dt) * phase) * nimbusPower)));
      T *= exp(((-(dn) * dt) * (*u).p_absorb));
      if ((T < 0.01f)) {
        break;
      }
    }
  }
  let body = (1f - T);
  scattered = (scattered + ((*u).c_shadow * (body * (*u).p_ambient)));
  return vec4f(scattered, body);
}

fn tanh3(x: vec3f) -> vec3f {
  let clamped = clamp(x, vec3f(-10), vec3f(10));
  let e = exp((clamped * 2f));
  return ((e - 1f) / (e + 1f));
}

struct orb21Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb21Fragment(_arg_0: orb21Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let nimbusPower = ((*u).p_power * (0.7f + (0.9f * (*u).outputVol)));
  let nimbusDensity = ((*u).p_density * (1f + (0.35f * (*u).inputVol)));
  let acc = nimbusRender(fragCoord, nimbusPower, nimbusDensity);
  let col = tanh3((acc.xyz * (*u).p_exposure));
  let a = clamp((acc.w * (*u).p_alphaGain), 0f, 1f);
  return vec4f(col, a);
}
