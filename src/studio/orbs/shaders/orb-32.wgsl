// Compiled from unchanged shadercn orb-32 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: ff1a4f4c92efc8a3f3d1cd6051d26eaab3dd3a8ba987ed73d0c3f997e8039c0f
struct orb32Params {
  anim: f32,
  c_core: vec3f,
  c_deep: vec3f,
  c_inner: vec3f,
  c_outer: vec3f,
  c_rim: vec3f,
  c_tint: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_absorb: f32,
  p_alphaGain: f32,
  p_armSharp: f32,
  p_arms: f32,
  p_beat: f32,
  p_breathe: f32,
  p_bulge: f32,
  p_camDist: f32,
  p_churn: f32,
  p_contrast: f32,
  p_core: f32,
  p_density: f32,
  p_edge: f32,
  p_edgeFade: f32,
  p_envRadius: f32,
  p_exposure: f32,
  p_falloff: f32,
  p_fill: f32,
  p_focal: f32,
  p_hueReach: f32,
  p_pulse: f32,
  p_ragged: f32,
  p_rim: f32,
  p_saturation: f32,
  p_spin: f32,
  p_starDensity: f32,
  p_starScale: f32,
  p_stars: f32,
  p_thick: f32,
  p_threshold: f32,
  p_tilt: f32,
  p_turbScale: f32,
  p_twinkle: f32,
  p_wind: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb32Params;

fn hash(p: vec2f) -> f32 {
  return fract((sin(dot(p, vec2f(127.0999984741211, 311.70001220703125))) * 43758.5453123f));
}

fn galaxy(p: vec3f, t: f32, galDensity: f32, galCore: f32, galFalloff: f32) -> vec3f {
  let u = (&params);
  let rho = length(p.xz);
  let h = p.y;
  let phi = select(0f, atan2(p.z, p.x), (rho > 1e-4f));
  let lr = log(max(rho, 0.02f));
  let armPhase = ((phi * (*u).p_arms) - ((*u).p_wind * lr));
  var q = (p * (*u).p_turbScale);
  var f = 1f;
  for (var i = 0u; i < 4u; i += 1u) {
    q = (q + (cos(((q.yzx * f) + t)) / f));
    f *= 1.9f;
  }
  let n = (((((sin(q.x) + sin(q.y)) + sin(q.z)) / 3f) * 0.5f) + 0.5f);
  let clump = smoothstep((*u).p_threshold, 1f, n);
  var arm = (0.5f + (0.5f * cos((armPhase + ((n - 0.5f) * (*u).p_ragged)))));
  arm = pow(arm, (*u).p_armSharp);
  let scaleH = ((*u).p_thick * (0.12f + rho));
  let disc = (exp((-(rho) * galFalloff)) * exp((-(abs(h)) / scaleH)));
  let bulge = exp((-(dot(p, p)) * (*u).p_bulge));
  let dens = (((disc * (0.08f + (1.6f * arm))) * (0.25f + (0.75f * clump))) + (bulge * galCore));
  return vec3f((dens * galDensity), arm, rho);
}

fn galaxyRender(fragCoord: vec2f, galDensity: f32, galCore: f32, galFalloff: f32) -> vec4f {
  let u = (&params);
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let ro = vec3f(0f, 0f, (*u).p_camDist);
  let rd = normalize(vec3f(uv, -((*u).p_focal)));
  let t = (*u).p_churn;
  let spin = (*u).p_spin;
  let ct = cos((*u).p_tilt);
  let st = sin((*u).p_tilt);
  let cs = cos(spin);
  let sn = sin(spin);
  var acc = vec3f();
  var trans = vec3f(1);
  let absorb = (vec3f(0.699999988079071, 1, 1.5) * (*u).p_absorb);
  var z = max(((*u).p_camDist - ((*u).p_envRadius * 1.05f)), 0f);
  let zEnd = ((*u).p_camDist + ((*u).p_envRadius * 1.05f));
  let dt = ((zEnd - z) / 56f);
  z += (dt * hash((fragCoord * 0.37f)));
  for (var i = 0u; i < 56u; i += 1u) {
    let p = (ro + (rd * z));
    let env = (1f - smoothstep(((*u).p_envRadius * 0.92f), (*u).p_envRadius, length(p)));
    if ((env > 1e-3f)) {
      var g = vec3f(p.x, ((p.y * ct) - (p.z * st)), ((p.y * st) + (p.z * ct)));
      g = vec3f(((g.x * cs) - (g.z * sn)), g.y, ((g.x * sn) + (g.z * cs)));
      let gs = galaxy((g / (*u).p_envRadius), t, galDensity, galCore, galFalloff);
      let arm = gs.y;
      let rho = gs.z;
      let dens = (gs.x * env);
      let ramp = mix((*u).c_inner, (*u).c_outer, smoothstep(0.12f, (*u).p_hueReach, rho));
      let coreW = exp((((-(rho) * rho) * (*u).p_bulge) * 0.6f));
      let emit = (mix(ramp, (*u).c_core, coreW) * (0.6f + (0.6f * arm)));
      acc = (acc + ((trans * (dens * dt)) * emit));
      trans = (trans * exp((absorb * (-(dens) * dt))));
    }
    z += dt;
    if (((trans.y < 4e-3f) || (z > zEnd))) {
      break;
    }
  }
  return vec4f(acc, (1f - trans.y));
}

fn starField(p: vec2f, density: f32, size: f32, twinkleT: f32) -> f32 {
  let id = floor(p);
  let f = fract(p);
  var acc = 0f;
  for (var i = 0u; i < 3u; i += 1u) {
    for (var i_1 = 0u; i_1 < 3u; i_1 += 1u) {
      let o = vec2f((f32(i_1) - 1f), (f32(i) - 1f));
      let cid = (id + o);
      let h = hash(cid);
      if ((h <= density)) {
        let sp = (o + vec2f(hash((cid + 1.3f)), hash((cid + 2.7f))));
        let dd = length((f - sp));
        let tw = (0.55f + (0.45f * sin(((twinkleT * (1.5f + (5f * hash((cid + 5.1f))))) + (h * 40f)))));
        let sz = (size * (0.5f + ((1.2f * hash((cid + 8.9f))) * hash((cid + 8.9f)))));
        acc += ((tw * exp(((-(dd) * dd) / (sz * sz)))) * (0.4f + ((0.6f * h) / max(density, 1e-3f))));
      }
    }
  }
  return acc;
}

fn tanh3(x: vec3f) -> vec3f {
  let clamped = clamp(x, vec3f(-10), vec3f(10));
  let e = exp((clamped * 2f));
  return ((e - 1f) / (e + 1f));
}

struct orb32Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb32Fragment(_arg_0: orb32Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let wave = (0.5f + (0.5f * cos((*u).p_beat)));
  let galDensity = ((*u).p_density * (1f + (0.35f * (*u).inputVol)));
  let galCore = (((*u).p_core * (1f + (0.7f * (*u).outputVol))) * (1f + ((*u).p_pulse * wave)));
  let galFalloff = ((*u).p_falloff / (1f + ((*u).p_breathe * wave)));
  var acc = galaxyRender(fragCoord, galDensity, galCore, galFalloff);
  let ro = vec3f(0f, 0f, (*u).p_camDist);
  let rd = normalize(vec3f(orbUv, -((*u).p_focal)));
  let ct = cos((*u).p_tilt);
  let st = sin((*u).p_tilt);
  let N = vec3f(0f, ct, st);
  let denom = dot(N, rd);
  if ((abs(denom) > 1e-4f)) {
    let th = (-(dot(N, ro)) / denom);
    let q = (ro + (rd * th));
    if (((th > 0f) && (dot(q, q) < (((*u).p_envRadius * (*u).p_envRadius) * 0.9f)))) {
      let g = (vec3f(q.x, ((q.y * ct) - (q.z * st)), ((q.y * st) + (q.z * ct))) / (*u).p_envRadius);
      let cs = cos((*u).p_spin);
      let sn = sin((*u).p_spin);
      let gp = vec2f(((g.x * cs) - (g.z * sn)), ((g.x * sn) + (g.z * cs)));
      let rho = length(gp);
      let phi = select(0f, atan2(gp.y, gp.x), (rho > 1e-4f));
      let armW = (0.5f + (0.5f * cos(((phi * (*u).p_arms) - ((*u).p_wind * log(max(rho, 0.02f)))))));
      let sf = starField((gp * (*u).p_starScale), ((*u).p_starDensity * (0.3f + (0.7f * armW))), 0.12f, (*u).p_twinkle);
      let veil = (1f - acc.w);
      let starLight = (vec3f(1, 0.9700000286102295, 0.8999999761581421) * (((sf * (*u).p_stars) * exp((-(rho) * 1.5f))) * (0.25f + (0.75f * veil))));
      acc = vec4f((acc.xyz + starLight), acc.w);
    }
  }
  var col = tanh3((acc.xyz / max((*u).p_exposure, 0.01f)));
  col = pow(clamp(col, vec3f(), vec3f(1)), vec3f((*u).p_contrast));
  let lum = dot(col, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464));
  col = mix(vec3f(lum), col, (*u).p_saturation);
  col = (col * (*u).c_tint);
  let peak = max(col.x, max(col.y, col.z));
  var a = clamp((peak * (*u).p_alphaGain), 0f, 1f);
  col = (col + ((*u).c_deep * (*u).p_fill));
  a = max(a, (*u).p_fill);
  let mrd = normalize(vec3f(orbUv, -((*u).p_focal)));
  let closest = length(cross(vec3f(0f, 0f, (*u).p_camDist), mrd));
  let band = mix(0.35f, 0.012f, clamp((*u).p_edge, 0f, 1f));
  let mask = (1f - smoothstep(((*u).p_envRadius * (1f - band)), ((*u).p_envRadius * 1.005f), closest));
  col = (col * mask);
  a *= mask;
  let fres = smoothstep(((*u).p_envRadius * 0.7f), (*u).p_envRadius, closest);
  col = (col + ((*u).c_rim * ((((*u).p_rim * fres) * fres) * mask)));
  let r2d = length(orbUv);
  let fade = (1f - smoothstep((*u).p_edgeFade, 1f, r2d));
  col = (col * fade);
  a *= fade;
  return vec4f(col, a);
}
