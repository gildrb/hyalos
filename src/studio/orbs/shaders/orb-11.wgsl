// Compiled from unchanged shadercn orb-11 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 5c50fb3bf01aef1b0d3dee90c9add7a8d6478d6cd7f37818fb546ac06c1282ab
struct orb11Params {
  anim: f32,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_baseVis: f32,
  p_chromaSpread: f32,
  p_flowAmp: f32,
  p_flowScale: f32,
  p_flowSpeed: f32,
  p_glow: f32,
  p_metalDark: f32,
  p_posScale: f32,
  p_precess: f32,
  p_probGain: f32,
  p_probPow: f32,
  p_radialDecay: f32,
  p_radialPow: f32,
  p_radius: f32,
  p_rotSpeed: f32,
  p_speed: f32,
  p_swell: f32,
  p_waveFreq: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb11Params;

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

struct orb11Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb11Fragment(_arg_0: orb11Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let r2d = length(uv);
  let R = ((*u).p_radius + ((*u).p_swell * (*u).inputVol));
  let mask = smoothstep(0.012f, -0.012f, (r2d - R));
  let nr = clamp((r2d / max(R, 1e-3f)), 0f, 1f);
  let z = sqrt(max((1f - (nr * nr)), 0f));
  let posScale = ((*u).p_posScale * ((0.8f + (0.45f * (*u).outputVol)) + (0.2f * (*u).inputVol)));
  let radialPow = ((*u).p_radialPow * (0.7f + (0.8f * (*u).outputVol)));
  let radialDecay = ((*u).p_radialDecay * (1.25f - (0.5f * (*u).outputVol)));
  let probPow = ((*u).p_probPow * (1.3f - (0.55f * (*u).outputVol)));
  let probGain = ((*u).p_probGain * ((0.7f + (0.6f * (*u).outputVol)) + (0.5f * (*u).inputVol)));
  let waveFreq = ((*u).p_waveFreq * (0.6f + (1f * (*u).outputVol)));
  let chromaSpread = ((*u).p_chromaSpread * ((0.6f + (0.9f * (*u).outputVol)) + (0.5f * (*u).inputVol)));
  let animTime = (*u).p_speed;
  let cosT = cos((animTime * (*u).p_rotSpeed));
  let sinT = sin((animTime * (*u).p_rotSpeed));
  let nxy = (uv / max(R, 1e-3f));
  let sp = (vec3f(nxy.x, nxy.y, z) * posScale);
  var pos = vec3f(((sp.x * cosT) - (sp.z * sinT)), sp.y, ((sp.x * sinT) + (sp.z * cosT)));
  let tilt = (sin(((animTime * 0.21f) + 1.7f)) * (*u).p_precess);
  let cx = cos(tilt);
  let sx = sin(tilt);
  pos = vec3f(pos.x, ((pos.y * cx) - (pos.z * sx)), ((pos.y * sx) + (pos.z * cx)));
  let flowT = (*u).p_flowSpeed;
  let fAmp = ((*u).p_flowAmp * ((0.7f + (0.6f * (*u).outputVol)) + (0.4f * (*u).inputVol)));
  let w = vec3f(fbm(((pos.yz * (*u).p_flowScale) + vec2f((flowT * 0.7f), (-(flowT) * 0.4f)))), fbm(((pos.zx * (*u).p_flowScale) + (vec2f((-(flowT) * 0.55f), (flowT * 0.62f)) + 3.7f))), fbm(((pos.xy * (*u).p_flowScale) + (vec2f((flowT * 0.5f), (flowT * 0.85f)) + 7.1f))));
  pos = (pos + ((w - 0.5f) * fAmp));
  let r = (length(pos) + 1e-3f);
  let theta = acos(clamp((pos.y / r), -1f, 1f));
  let phi = atan2(pos.z, pos.x);
  const a0 = 0.5f;
  let rho = ((2f * r) / (5f * a0));
  let radial = (pow(rho, radialPow) * exp((-(rho) / radialDecay)));
  let angular = (pow(sin(theta), 3f) * cos((phi + (animTime * 0.2f))));
  let psi = (radial * angular);
  var probability = (psi * psi);
  let waveN = max(1f, floor((waveFreq + 0.5f)));
  let wavePhase = (((phi * waveN) + (theta * 2.5f)) - (animTime * 2f));
  probability *= (0.85f + (0.15f * sin(wavePhase)));
  let patches = fbm(((pos.xy * 1.6f) + vec2f((flowT * 0.4f), (-(flowT) * 0.3f))));
  probability *= (0.65f + (0.7f * patches));
  probability = (pow(probability, probPow) * probGain);
  probability = clamp(probability, 0f, 1f);
  let fresnel = pow((1f - z), 1.5f);
  let chromaOffset = ((((phi * 2f) + (theta * 1.5f)) + (animTime * 0.3f)) + (probability * 3f));
  let rainbowRaw = vec3f(((sin(chromaOffset) * 0.5f) + 0.5f), ((sin((chromaOffset + chromaSpread)) * 0.5f) + 0.5f), ((sin((chromaOffset + (chromaSpread * 2f))) * 0.5f) + 0.5f));
  let rainbow = (normalize((rainbowRaw + 0.01f)) * length(rainbowRaw));
  let bandFreq = ((chromaOffset * 3f) + (fresnel * 2.4f));
  let chromaticBands = vec3f(((sin(bandFreq) * 0.5f) + 0.5f), ((sin((bandFreq + 2.094f)) * 0.5f) + 0.5f), ((sin((bandFreq + 4.189f)) * 0.5f) + 0.5f));
  var glowColor = mix(rainbow, chromaticBands, 0.12f);
  glowColor = pow(glowColor, vec3f(0.800000011920929));
  let darkMetal = vec3f((*u).p_metalDark);
  let lightMetal = mix(vec3f(0.8999999761581421, 0.9200000166893005, 0.949999988079071), glowColor, 0.7f);
  let metalGradient = smoothstep(0f, 1f, ((probability * 0.7f) + (fresnel * 0.3f)));
  let metalColor = mix(darkMetal, lightMetal, metalGradient);
  let orbGlow = ((*u).p_glow + (0.6f * (*u).outputVol));
  let totalGlow = (((0.25f + (fresnel * 0.6f)) + (probability * 0.8f)) * orbGlow);
  let glowAmount = clamp(pow(totalGlow, 0.7f), 0f, 1f);
  var surfaceColor = mix(metalColor, glowColor, glowAmount);
  let normal = vec3f(nxy.x, nxy.y, z);
  let specular = pow(max(dot(normal, vec3f(0.40824830532073975, 0.40824830532073975, 0.8164966106414795)), 0f), 32f);
  surfaceColor = (surfaceColor + (mix(vec3f(1), glowColor, 0.6f) * (specular * 0.4f)));
  let visibility = clamp(((((probability * 1.2f) + (fresnel * 0.3f)) + (*u).p_baseVis) + ((*u).inputVol * 0.15f)), 0f, 1f);
  let alpha = (mask * visibility);
  return vec4f((surfaceColor * alpha), alpha);
}
