// Compiled from unchanged shadercn orb-12 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 4db55113a492f7ab857332b1521e912b61c8b29e744fb8a78c38cedb027ba84e
struct orb12Params {
  anim: f32,
  c_brickA: vec3f,
  c_brickB: vec3f,
  c_brickC: vec3f,
  c_brickD: vec3f,
  c_brickE: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_contrast: f32,
  p_gain: f32,
  p_gap: f32,
  p_gloss: f32,
  p_light: f32,
  p_patch: f32,
  p_radius: f32,
  p_rebuild: f32,
  p_seam: f32,
  p_spin: f32,
  p_stud: f32,
  p_studs: f32,
  p_tilt: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb12Params;

fn rot2(angle: f32) -> mat2x2f {
  let c = cos(angle);
  let s = sin(angle);
  return mat2x2f(vec2f(c, -(s)), vec2f(s, c));
}

fn hash(p: vec2f) -> f32 {
  return fract((sin(dot(p, vec2f(127.0999984741211, 311.70001220703125))) * 43758.5453123f));
}

struct BrickHit {
  bid: vec3f,
  off: f32,
  orient: f32,
}

fn lgBrick(cellIdx: vec3f) -> BrickHit {
  let orient = (cellIdx.y - (2f * floor((cellIdx.y / 2f))));
  let lc = select(cellIdx.z, cellIdx.x, (orient < 0.5f));
  let sc = select(cellIdx.x, cellIdx.z, (orient < 0.5f));
  let srow = floor((sc / 2f));
  let off = floor((hash(vec2f((cellIdx.y * 3.17f), (srow * 7.31f))) * 4f));
  let bid = vec3f(floor(((lc + off) / 4f)), cellIdx.y, (srow + (orient * 913f)));
  return BrickHit(bid, off, orient);
}

fn lgSolid(cc: vec3f, cell: vec3f, gap: f32) -> f32 {
  let u = (&params);
  let r = length(cc);
  if ((r >= 1f)) {
    return 0f;
  }
  if ((r > (1f - (2.2f * cell.y)))) {
    let brick = lgBrick(floor((cc / cell)));
    let blink = fract((hash(((brick.bid.xy * 0.173f) + (brick.bid.z * 0.089f))) + ((*u).p_rebuild * 0.03f)));
    if ((blink < gap)) {
      return 0f;
    }
  }
  return 1f;
}

fn noise(p: vec2f) -> f32 {
  let i = floor(p);
  let f = fract(p);
  let ff = ((f * f) * (vec2f(3) - (f * 2f)));
  return mix(mix(hash(i), hash((i + vec2f(1, 0))), ff.x), mix(hash((i + vec2f(0, 1))), hash((i + vec2f(1))), ff.x), ff.y);
}

struct orb12Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb12Fragment(_arg_0: orb12Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let glossNow = ((*u).p_gloss * (0.7f + (0.9f * (*u).outputVol)));
  let gainNow = ((*u).p_gain * (0.92f + (0.25f * (*u).outputVol)));
  let lightNow = ((*u).p_light * (1f + (0.3f * (*u).inputVol)));
  let pitch = (2f / clamp((*u).p_studs, 8f, 48f));
  let cell = vec3f(pitch, (pitch * 1.2f), pitch);
  let gap = clamp((*u).p_gap, 0f, 0.9f);
  let bound = ((1f + (length(cell) * 0.5f)) + 1e-3f);
  let duv = (uv / (*u).p_radius);
  var ro = vec3f((duv.x * bound), (duv.y * bound), 2.6f);
  var rd = vec3f(0, 0, -1);
  let tiltM = rot2((*u).p_tilt);
  let spinM = rot2(-((*u).p_spin));
  let roT = (tiltM * vec2f(ro.y, ro.z));
  ro = vec3f(ro.x, roT.x, roT.y);
  let roS = (spinM * vec2f(ro.x, ro.z));
  ro = vec3f(roS.x, ro.y, roS.y);
  let rdT = (tiltM * vec2f(rd.y, rd.z));
  rd = vec3f(rd.x, rdT.x, rdT.y);
  let rdS = (spinM * vec2f(rd.x, rd.z));
  rd = vec3f(rdS.x, rd.y, rdS.y);
  var Lo = vec3f(-0.48970210552215576, 0.6855829358100891, 0.5386723279953003);
  let loT = (tiltM * vec2f(Lo.y, Lo.z));
  Lo = vec3f(Lo.x, loT.x, loT.y);
  let loS = (spinM * vec2f(Lo.x, Lo.z));
  Lo = vec3f(loS.x, Lo.y, loS.y);
  var Vo = vec3f(0, 0, 1);
  let voT = (tiltM * vec2f(Vo.y, Vo.z));
  Vo = vec3f(Vo.x, voT.x, voT.y);
  let voS = (spinM * vec2f(Vo.x, Vo.z));
  Vo = vec3f(voS.x, Vo.y, voS.y);
  let sgn = vec3f(f32(select(-1i, 1i, (rd.x >= 0f))), f32(select(-1i, 1i, (rd.y >= 0f))), f32(select(-1i, 1i, (rd.z >= 0f))));
  rd = normalize((sgn * max(abs(rd), vec3f(9.999999747378752e-5))));
  let b = dot(rd, ro);
  let c = (dot(ro, ro) - (bound * bound));
  let disc = ((b * b) - c);
  if ((disc < 0f)) {
    return vec4f();
  }
  let sq = sqrt(disc);
  let p0 = (ro + (rd * ((-(b) - sq) + (pitch * 1e-3f))));
  let tSpan = (2f * sq);
  var vp = floor((p0 / cell));
  let tDelta = (cell / abs(rd));
  var tMax = ((((vp + step(vec3f(), rd)) * cell) - p0) / rd);
  var hitF = 0f;
  var mask = vec3f(0, 0, 1);
  var tCur = 0f;
  for (var i = 0u; i < 96u; i += 1u) {
    if ((lgSolid(((vp + 0.5f) * cell), cell, gap) > 0.5f)) {
      hitF = 1f;
      break;
    }
    if (((tMax.x < tMax.y) && (tMax.x < tMax.z))) {
      tCur = tMax.x;
      tMax = vec3f((tMax.x + tDelta.x), tMax.y, tMax.z);
      vp = vec3f((vp.x + sgn.x), vp.y, vp.z);
      mask = vec3f(1, 0, 0);
    }
    else {
      if ((tMax.y < tMax.z)) {
        tCur = tMax.y;
        tMax = vec3f(tMax.x, (tMax.y + tDelta.y), tMax.z);
        vp = vec3f(vp.x, (vp.y + sgn.y), vp.z);
        mask = vec3f(0, 1, 0);
      }
      else {
        tCur = tMax.z;
        tMax = vec3f(tMax.x, tMax.y, (tMax.z + tDelta.z));
        vp = vec3f(vp.x, vp.y, (vp.z + sgn.z));
        mask = vec3f(0, 0, 1);
      }
    }
    if ((tCur > tSpan)) {
      break;
    }
  }
  if ((hitF < 0.5f)) {
    return vec4f();
  }
  let cc = ((vp + 0.5f) * cell);
  let r = length(cc);
  let dir = (cc / max(r, 1e-4f));
  let brick = lgBrick(vp);
  let n = ((mask * sgn) * -1f);
  let hp = (p0 + (rd * tCur));
  let cph = hash(((brick.bid.xy * 1.37f) + (brick.bid.z * 0.91f)));
  var rn = ((noise(((dir.xy * 2.6f) + 7f)) * 0.5f) + (noise(((dir.yz * 2.6f) + 13f)) * 0.5f));
  rn = clamp((0.5f + ((rn - 0.5f) * 2.2f)), 0f, 0.999f);
  let idx = floor((clamp(mix(cph, rn, clamp((*u).p_patch, 0f, 1f)), 0f, 0.999f) * 5f));
  var albedo = select(select(select(select((*u).c_brickE, (*u).c_brickD, (idx < 3.5f)), (*u).c_brickC, (idx < 2.5f)), (*u).c_brickB, (idx < 1.5f)), (*u).c_brickA, (idx < 0.5f));
  albedo = (albedo * (0.93f + (0.14f * hash(((brick.bid.xy * 0.53f) + (brick.bid.z * 1.7f))))));
  let sp = (hp / cell);
  let lcC = select(sp.z, sp.x, (brick.orient < 0.5f));
  let scC = select(sp.x, sp.z, (brick.orient < 0.5f));
  let u4 = fract(((lcC + brick.off) / 4f));
  let v2 = fract((scC / 2f));
  let wY = fract(sp.y);
  let dL = ((min(u4, (1f - u4)) * 4f) * pitch);
  let dS = ((min(v2, (1f - v2)) * 2f) * pitch);
  let dY = (min(wY, (1f - wY)) * cell.y);
  var seamD = 0f;
  if ((mask.y > 0.5f)) {
    seamD = min(dL, dS);
  }
  else {
    if ((mask.x > 0.5f)) {
      seamD = min(dY, select(dL, dS, (brick.orient < 0.5f)));
    }
    else {
      seamD = min(dY, select(dS, dL, (brick.orient < 0.5f)));
    }
  }
  let seam = ((1f - smoothstep(0f, (0.07f * pitch), seamD)) * clamp((*u).p_seam, 0f, 1f));
  var nEff = n;
  var studF = 0f;
  var shadowF = 0f;
  var engrave = 0f;
  let studAmt = clamp((*u).p_stud, 0f, 1f);
  if (((mask.y > 0.5f) && (n.y > 0.5f))) {
    let cuv = (fract((hp.xz / pitch)) - 0.5f);
    let sd = length(cuv);
    let rim = (smoothstep(0.14f, 0.29f, sd) * (1f - smoothstep(0.29f, 0.335f, sd)));
    let tiltN = normalize(vec3f(cuv.x, 0.42f, cuv.y));
    nEff = normalize(mix(n, tiltN, (rim * studAmt)));
    studF = (1f - smoothstep(0.285f, 0.33f, sd));
    let lxz = normalize((Lo.xz + vec2f(9.999999747378752e-6)));
    let away = clamp(dot(normalize((cuv + vec2f(9.999999747378752e-6))), (lxz * -1f)), 0f, 1f);
    shadowF = ((smoothstep(0.47f, 0.335f, sd) * (1f - studF)) * (0.35f + (0.65f * away)));
    engrave = ((smoothstep(0.11f, 0.135f, sd) * (1f - smoothstep(0.155f, 0.18f, sd))) * studF);
  }
  let lam = clamp(dot(nEff, Lo), 0f, 1f);
  let wrap = clamp(((dot(dir, Lo) * 0.5f) + 0.5f), 0f, 1f);
  let depthDim = mix(1f, 0.55f, clamp(((1f - r) / (3f * cell.y)), 0f, 1f));
  let shade = (((0.34f + ((0.42f * wrap) * wrap)) + ((0.8f * lam) * lightNow)) * depthDim);
  var col = ((albedo * shade) * (1f + (0.1f * studF)));
  col = (col * (1f - ((shadowF * 0.38f) * studAmt)));
  col = (col * (1f - ((engrave * 0.14f) * studAmt)));
  let bevel = (smoothstep((0.05f * pitch), (0.085f * pitch), seamD) * (1f - smoothstep((0.085f * pitch), (0.16f * pitch), seamD)));
  col = (col + (albedo * ((bevel * (0.18f + (0.5f * lam))) * clamp((*u).p_seam, 0f, 1f))));
  col = (col * (1f - (seam * 0.8f)));
  let ndh = clamp(dot(nEff, normalize((Lo + Vo))), 0f, 1f);
  let spec = (pow(ndh, 48f) + (0.22f * pow(ndh, 8f)));
  col = (col + (vec3f(1) * (((spec * glossNow) * (1f - seam)) * depthDim)));
  col = (col * gainNow);
  col = pow(max(col, vec3f()), vec3f((*u).p_contrast));
  return vec4f(col, 1f);
}
