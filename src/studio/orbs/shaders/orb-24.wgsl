// Compiled from unchanged shadercn orb-24 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 1cff0b1f55284351ad8d5909f3e4795bcb0090e149904947b4b4021b8084b446
struct orb24Params {
  anim: f32,
  c_dirt: vec3f,
  c_grass: vec3f,
  c_lava: vec3f,
  c_leaf: vec3f,
  c_ore: vec3f,
  c_sand: vec3f,
  c_stone: vec3f,
  c_water: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_blocks: f32,
  p_cave: f32,
  p_contrast: f32,
  p_core: f32,
  p_drift: f32,
  p_gain: f32,
  p_glow: f32,
  p_light: f32,
  p_ore: f32,
  p_radius: f32,
  p_rough: f32,
  p_scale: f32,
  p_sea: f32,
  p_season: f32,
  p_shuffle: f32,
  p_spin: f32,
  p_texture: f32,
  p_tilt: f32,
  p_trees: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb24Params;

struct World {
  cherry: f32,
  clim: vec4f,
  drift: vec3f,
  maxH: f32,
  seaN: f32,
  treeMul: f32,
  vs: f32,
}

fn rot2(angle: f32) -> mat2x2f {
  let c = cos(angle);
  let s = sin(angle);
  return mat2x2f(vec2f(c, -(s)), vec2f(s, c));
}

fn hash(p: vec2f) -> f32 {
  return fract((sin(dot(p, vec2f(127.0999984741211, 311.70001220703125))) * 43758.5453123f));
}

fn noise(p: vec2f) -> f32 {
  let i = floor(p);
  let f = fract(p);
  let ff = ((f * f) * (vec2f(3) - (f * 2f)));
  return mix(mix(hash(i), hash((i + vec2f(1, 0))), ff.x), mix(hash((i + vec2f(0, 1))), hash((i + vec2f(1))), ff.x), ff.y);
}

fn ckN3(p: vec3f) -> f32 {
  let v = (((noise(p.xy) + noise((p.yz + 19.1f))) + noise((p.zx + 47.3f))) / 3f);
  return clamp((0.5f + ((v - 0.5f) * 1.9f)), 0f, 1f);
}

fn ckField(dir: vec3f, world: World) -> f32 {
  let u = (&params);
  let q = ((dir * (*u).p_scale) + world.drift);
  return ((ckN3(q) * 0.65f) + (ckN3(((q * 2.6f) + 31.7f)) * 0.35f));
}

fn ckTerrain(dir: vec3f, world: World) -> f32 {
  let u = (&params);
  let h = (1f + ((((*u).p_rough * max((ckField(dir, world) - world.seaN), 0f)) * 1.2f) * (1f + (world.clim.w * 0.8f))));
  let stepH = (3f * world.vs);
  let hq = (1f + (floor(((h - 1f) / stepH)) * stepH));
  return mix(h, hq, (world.clim.w * 0.85f));
}

struct TreeCell {
  dir: vec3f,
  h1: f32,
  h2: f32,
}

fn ckTreeCell(dir: vec3f) -> TreeCell {
  let u = (&params);
  let ad = abs(dir);
  var fuv = vec2f();
  var face = 0f;
  if (((ad.x >= ad.y) && (ad.x >= ad.z))) {
    fuv = (dir.yz / ad.x);
    face = f32(select(1i, 0i, (dir.x > 0f)));
  }
  else {
    if ((ad.y >= ad.z)) {
      fuv = (dir.xz / ad.y);
      face = f32(select(3i, 2i, (dir.y > 0f)));
    }
    else {
      fuv = (dir.xy / ad.z);
      face = f32(select(5i, 4i, (dir.z > 0f)));
    }
  }
  let grid = max(((*u).p_blocks / 6f), 2f);
  let cell = floor((((fuv * 0.5f) + 0.5f) * grid));
  let h1 = hash(((cell * 1.17f) + (face * 19.3f)));
  let h2 = hash(((cell * 0.71f) + ((face * 7.7f) + 9.3f)));
  let jit = (vec2f(hash((cell + (7.1f + face))), hash((cell + (13.7f + face)))) - 0.5f);
  let auv = (((((cell + 0.5f) + (jit * 0.3f)) / grid) * 2f) - 1f);
  var cp = vec3f();
  if ((face < 1.5f)) {
    cp = vec3f(f32(select(-1i, 1i, (face < 0.5f))), auv.x, auv.y);
  }
  else {
    if ((face < 3.5f)) {
      cp = vec3f(auv.x, f32(select(-1i, 1i, (face < 2.5f))), auv.y);
    }
    else {
      cp = vec3f(auv.x, auv.y, f32(select(-1i, 1i, (face < 4.5f))));
    }
  }
  return TreeCell(normalize(cp), h1, h2);
}

fn ckBiome(dir: vec3f, world: World) -> f32 {
  return ckN3((((dir * 1.3f) + world.drift) + 57.9f));
}

fn ckTreeMaterial(cc: vec3f, treeDir: vec3f, h2: f32, r: f32, ha: f32, lat: f32, world: World) -> f32 {
  if ((world.clim.z > 0.5f)) {
    let spikeH = ((2f + ((6f * h2) * h2)) * world.vs);
    let w = (mix(1.15f, 0.3f, clamp(((r - ha) / spikeH), 0f, 1f)) * world.vs);
    if ((((lat < w) && (r > (ha - world.vs))) && (r < (ha + spikeH)))) {
      return 3f;
    }
  }
  else {
    if ((world.clim.w > 0.5f)) {
      let cacH = ((1.5f + (2f * h2)) * world.vs);
      if ((((lat < (0.6f * world.vs)) && (r > (ha - world.vs))) && (r < (ha + cacH)))) {
        return 3f;
      }
    }
    else {
      if ((world.cherry > 0.5f)) {
        let trunkTop = (ha + ((2f + (1.5f * h2)) * world.vs));
        if ((((lat < (0.75f * world.vs)) && (r > (ha - world.vs))) && (r < trunkTop))) {
          return 2f;
        }
        var dd = (cc - (treeDir * (trunkTop + (0.6f * world.vs))));
        dd = (dd + (treeDir * (dot(dd, treeDir) * 0.8f)));
        let lv = floor((cc / world.vs));
        let rag = hash(((lv.xy * 0.61f) + (lv.z * 2.23f)));
        if ((length(dd) < ((2.2f + (0.5f * rag)) * world.vs))) {
          return 3f;
        }
      }
      else {
        let trunkTop = (ha + ((2.5f + (2f * h2)) * world.vs));
        if ((((lat < (0.75f * world.vs)) && (r > (ha - world.vs))) && (r < trunkTop))) {
          return 2f;
        }
        let dd = (cc - (treeDir * (trunkTop + (0.7f * world.vs))));
        let lv = floor((cc / world.vs));
        let rag = hash(((lv.xy * 0.61f) + (lv.z * 2.23f)));
        if ((length(dd) < ((1.7f + (0.5f * rag)) * world.vs))) {
          return 3f;
        }
      }
    }
  }
  return 0f;
}

fn ckVoxel(cc: vec3f, world: World) -> f32 {
  let u = (&params);
  let r = length(cc);
  let dir = (cc / max(r, 1e-4f));
  if ((r < world.maxH)) {
    let h = ckTerrain(dir, world);
    if ((r < h)) {
      if ((h > (1f + (1.5f * world.vs)))) {
        let cv = ckN3(((cc * ((*u).p_scale * 1.9f)) + 71.3f));
        let cw = (((*u).p_cave * 0.16f) * smoothstep(world.maxH, (world.maxH - 0.45f), r));
        if ((abs((cv - 0.5f)) < cw)) {
          return 0f;
        }
      }
      return 1f;
    }
  }
  if (((r >= (world.maxH + (8f * world.vs))) || ((*u).p_trees <= 1e-3f))) {
    return 0f;
  }
  let tree = ckTreeCell(dir);
  let thrMax = (clamp((*u).p_trees, 0f, 1f) * 0.8f);
  if ((tree.h1 <= (1f - thrMax))) {
    return 0f;
  }
  let bioA = ckBiome(tree.dir, world);
  var dens = select(select(0f, 0.25f, (bioA > 0.3f)), 1f, (bioA > 0.58f));
  dens *= world.treeMul;
  if ((tree.h1 <= (1f - (thrMax * dens)))) {
    return 0f;
  }
  let fA = ckField(tree.dir, world);
  let ha = (1f + (((*u).p_rough * max((fA - world.seaN), 0f)) * 1.2f));
  if (((fA <= (world.seaN + 0.015f)) || (ha >= (1f + ((*u).p_rough * 0.42f))))) {
    return 0f;
  }
  let lat = length((cc - (tree.dir * dot(cc, tree.dir))));
  return ckTreeMaterial(cc, tree.dir, tree.h2, r, ha, lat, world);
}

struct orb24Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb24Fragment(_arg_0: orb24Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let glowNow = ((*u).p_glow * (0.7f + (1f * (*u).outputVol)));
  let gainNow = ((*u).p_gain * (0.9f + (0.3f * (*u).outputVol)));
  let lightNow = ((*u).p_light * (1f + (0.3f * (*u).inputVol)));
  let drift = vec3f(((*u).p_drift * 0.31f), ((*u).p_drift * 0.17f), (-((*u).p_drift) * 0.23f));
  let t5 = (fract(((*u).p_season * 0.05f)) * 5f);
  let clim = vec4f(clamp((1f - min(abs(t5), abs((t5 - 5f)))), 0f, 1f), clamp((1f - abs((t5 - 4f))), 0f, 1f), clamp((1f - abs((t5 - 2f))), 0f, 1f), clamp((1f - abs((t5 - 3f))), 0f, 1f));
  let cherry = clamp((1f - abs((t5 - 1f))), 0f, 1f);
  let treeMul = (dot(clim, vec4f(1, 0.15000000596046448, 0.8999999761581421, 0.30000001192092896)) + (cherry * 0.9f));
  let vs = (2f / clamp((*u).p_blocks, 8f, 96f));
  let seaN = (0.25f + (clamp((*u).p_sea, 0f, 1f) * 0.5f));
  let maxH = ((1f + ((((*u).p_rough * (1f - seaN)) * 1.2f) * 1.8f)) + 1e-3f);
  let bound = (maxH + (8.5f * vs));
  let world = World(cherry, clim, drift, maxH, seaN, treeMul, vs);
  let duv = (orbUv / (*u).p_radius);
  var ro = vec3f((duv.x * bound), (duv.y * bound), 2.9f);
  var rd = vec3f(0, 0, -1);
  let tiltM = rot2((*u).p_tilt);
  let spinM = rot2(-((*u).p_spin));
  let roYZ = (tiltM * vec2f(ro.y, ro.z));
  ro = vec3f(ro.x, roYZ.x, roYZ.y);
  let roXZ = (spinM * vec2f(ro.x, ro.z));
  ro = vec3f(roXZ.x, ro.y, roXZ.y);
  let rdYZ = (tiltM * vec2f(rd.y, rd.z));
  rd = vec3f(rd.x, rdYZ.x, rdYZ.y);
  let rdXZ = (spinM * vec2f(rd.x, rd.z));
  rd = vec3f(rdXZ.x, rd.y, rdXZ.y);
  var Lo = vec3f(-0.48970210552215576, 0.6855829358100891, 0.5386723279953003);
  let loYZ = (tiltM * vec2f(Lo.y, Lo.z));
  Lo = vec3f(Lo.x, loYZ.x, loYZ.y);
  let loXZ = (spinM * vec2f(Lo.x, Lo.z));
  Lo = vec3f(loXZ.x, Lo.y, loXZ.y);
  let sgn = vec3f(f32(select(-1i, 1i, (rd.x >= 0f))), f32(select(-1i, 1i, (rd.y >= 0f))), f32(select(-1i, 1i, (rd.z >= 0f))));
  rd = normalize((sgn * max(abs(rd), vec3f(9.999999747378752e-5))));
  let b = dot(rd, ro);
  let c = (dot(ro, ro) - (bound * bound));
  let disc = ((b * b) - c);
  if ((disc < 0f)) {
    return vec4f();
  }
  let sq = sqrt(disc);
  let p0 = (ro + (rd * ((-(b) - sq) + (vs * 1e-3f))));
  let tSpan = (2f * sq);
  var vp = floor((p0 / vs));
  let tDelta = (vec3f(vs) / abs(rd));
  var tMax = ((((vp + step(vec3f(), rd)) * vs) - p0) / rd);
  var mat = 0f;
  var mask = vec3f(0, 0, 1);
  var tCur = 0f;
  for (var i = 0u; i < 160u; i += 1u) {
    let m = ckVoxel(((vp + 0.5f) * vs), world);
    if ((m > 0.5f)) {
      mat = m;
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
  if ((mat < 0.5f)) {
    return vec4f();
  }
  let cc = ((vp + 0.5f) * vs);
  let r = length(cc);
  let dir = (cc / max(r, 1e-4f));
  let n = ((mask * sgn) * -1f);
  let hp = (p0 + (rd * tCur));
  let vseed = vec2f(dot(vp, vec3f(1, 57, 113)), dot(vp, vec3f(27, 7, 91)));
  let h1 = hash((vseed * 0.013f));
  let h2 = hash(((vseed * 0.029f) + 5.7f));
  var uvFace = vec2f();
  if ((mask.x > 0.5f)) {
    uvFace = hp.yz;
  }
  else {
    if ((mask.y > 0.5f)) {
      uvFace = hp.xz;
    }
    else {
      uvFace = hp.xy;
    }
  }
  let grain = hash(((floor((fract((uvFace / vs)) * 4f)) * 0.37f) + (vseed * 0.11f)));
  var texMul = mix(1f, (0.72f + (0.55f * grain)), (*u).p_texture);
  let lam = clamp(dot(n, Lo), 0f, 1f);
  let wrap = clamp(((dot(dir, Lo) * 0.5f) + 0.5f), 0f, 1f);
  let ao = (0.55f + (0.45f * clamp(((dot(n, dir) * 0.5f) + 0.5f), 0f, 1f)));
  let shade = (((0.32f + ((0.5f * wrap) * wrap)) + ((0.85f * lam) * lightNow)) * ao);
  var col = vec3f();
  if ((mat < 1.5f)) {
    let f = ckField(dir, world);
    let h = (1f + (((*u).p_rough * max((f - seaN), 0f)) * 1.2f));
    let depth = (h - r);
    let topF = step(depth, (vs * 1.15f));
    let snow = vec3f(0.9200000166893005, 0.949999988079071, 1);
    let layer = hash(vec2f((floor((r / (vs * 2f))) * 0.371f), 5.3f));
    let mesaBand = select(select(select(select(vec3f(0.4000000059604645, 0.25, 0.18000000715255737), vec3f(0.8399999737739563, 0.6499999761581421, 0.27000001072883606), (layer < 0.9f)), vec3f(0.8799999952316284, 0.7900000214576721, 0.6700000166893005), (layer < 0.8f)), vec3f(0.6299999952316284, 0.25999999046325684, 0.15000000596046448), (layer < 0.68f)), vec3f(0.7400000095367432, 0.41999998688697815, 0.20999999344348907), (layer < 0.5f));
    let mesaTop = mix(vec3f(0.7200000286102295, 0.3799999952316284, 0.20000000298023224), mesaBand, step((1f + ((*u).p_rough * 0.1f)), h));
    let climGrass = ((((((*u).c_grass * clim.x) + ((*u).c_sand * clim.y)) + (snow * clim.z)) + (mesaTop * clim.w)) + (mix((*u).c_grass, vec3f(0.6200000047683716, 0.8500000238418579, 0.30000001192092896), 0.6f) * cherry));
    let climDirt = ((((*u).c_dirt * ((clim.x + clim.y) + cherry)) + (((*u).c_dirt * vec3f(0.75, 0.8500000238418579, 1.0499999523162842)) * clim.z)) + (mesaBand * clim.w));
    let climSand = ((((*u).c_sand * ((clim.x + clim.y) + cherry)) + (mix((*u).c_sand, snow, 0.9f) * clim.z)) + (vec3f(0.7200000286102295, 0.3499999940395355, 0.20000000298023224) * clim.w));
    let climWater = ((((*u).c_water * ((clim.x + clim.y) + cherry)) + (vec3f(0.6200000047683716, 0.8199999928474426, 0.9200000166893005) * clim.z)) + (mix((*u).c_water, vec3f(0.41999998688697815, 0.30000001192092896, 0.2199999988079071), 0.4f) * clim.w));
    if (((topF > 0.5f) && (f < seaN))) {
      let deep = (clamp(((seaN - f) / 0.12f), 0f, 1f) * (1f - (0.55f * clim.z)));
      let wc = (climWater * mix(1.3f, 0.55f, deep));
      var shim = (0.85f + (0.25f * sin(((((*u).anim * 2.5f) + (grain * 6.2831f)) + (dir.x * 4f)))));
      shim = mix(shim, 1.02f, clim.z);
      col = (((wc * (0.45f + (0.55f * wrap))) * shim) + (wc * (lam * 0.35f)));
    }
    else {
      let dirtF = step(depth, (vs * 2.4f));
      let up = clamp(dot(n, dir), 0f, 1f);
      var albedo = mix((*u).c_stone, climDirt, dirtF);
      albedo = mix(albedo, (*u).c_stone, ((dirtF * (1f - topF)) * step(h2, 0.3f)));
      let bio = ckBiome(dir, world);
      let desertF = step(bio, 0.3f);
      albedo = mix(albedo, climGrass, ((topF * step(0.45f, up)) * (1f - desertF)));
      albedo = mix(albedo, climSand, (desertF * dirtF));
      albedo = mix(albedo, climDirt, (((topF * step((1f + ((*u).p_rough * 0.28f)), h)) * 0.85f) * (1f - (0.9f * clim.z))));
      albedo = mix(albedo, (*u).c_stone, ((topF * step((1f + ((*u).p_rough * 0.45f)), h)) * (1f - (0.85f * clim.z))));
      albedo = mix(albedo, climSand, (topF * step(abs(((f - seaN) - 0.017f)), 0.018f)));
      let oc = floor((cc / (2.5f * vs)));
      let oseed = vec2f(dot(oc, vec3f(1, 57, 113)), dot(oc, vec3f(27, 7, 91)));
      let fleck = step(0.5f, hash(((floor((fract((uvFace / vs)) * 4f)) * 0.53f) + (oseed * 0.19f))));
      let icePatch = ((clim.z * step(hash(((oseed * 0.023f) + 9.1f)), 0.5f)) * step((1f + ((*u).p_rough * 0.06f)), h));
      albedo = mix(albedo, vec3f(0.550000011920929, 0.699999988079071, 0.9200000166893005), (icePatch * (0.45f + (0.4f * fleck))));
      let veinF = (((1f - dirtF) * step((1f - (*u).p_ore), hash((oseed * 0.017f)))) * step(h1, 0.8f));
      let oreType = hash(((oseed * 0.041f) + 2.9f));
      let oreHue = select(select(vec3f(0.1599999964237213), ((*u).c_ore * vec3f(0.25, 0.44999998807907104, 1.2000000476837158)), (oreType < 0.75f)), (*u).c_ore, (oreType < 0.4f));
      let oreLit = select(0i, 1i, (oreType < 0.75f));
      albedo = mix(albedo, oreHue, (veinF * (0.2f + (0.65f * fleck))));
      let twinkle = (0.55f + (0.45f * sin(((*u).p_shuffle + (hash((oseed * 0.013f)) * 37f)))));
      let depthDim = mix(1f, 0.62f, clamp((depth / max(((*u).p_rough * 0.9f), 0.05f)), 0f, 1f));
      let coreR = (1f - ((*u).p_rough * 0.6f));
      let coreF = ((*u).p_core * smoothstep((coreR + 0.15f), (coreR - 0.05f), r));
      let emis = ((oreHue * ((((veinF * fleck) * f32(oreLit)) * glowNow) * twinkle)) + (((*u).c_lava * (coreF * (0.9f + (0.4f * sin((((*u).p_shuffle * 1.6f) + (h1 * 51f))))))) * (0.6f + (1.4f * (*u).outputVol))));
      col = ((albedo * (shade * depthDim)) + emis);
    }
  }
  else {
    if ((mat < 2.5f)) {
      col = ((*u).c_dirt * (0.5f * shade));
    }
    else {
      let climLeaf = (((((*u).c_leaf * (clim.x + (clim.y * 0.9f))) + (vec3f(0.6200000047683716, 0.7599999904632568, 0.949999988079071) * clim.z)) + (mix((*u).c_leaf, vec3f(0.44999998807907104, 0.6200000047683716, 0.25), 0.5f) * clim.w)) + (vec3f(0.9300000071525574, 0.699999988079071, 0.8199999928474426) * cherry));
      col = (climLeaf * shade);
      let leafGrain = mix((0.5f + (0.9f * grain)), (0.85f + (0.3f * grain)), clim.z);
      texMul = mix(1f, leafGrain, (*u).p_texture);
    }
  }
  col = (col * (texMul * gainNow));
  col = pow(max(col, vec3f()), vec3f((*u).p_contrast));
  return vec4f(col, 1f);
}
