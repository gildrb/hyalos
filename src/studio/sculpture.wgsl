// Derived from glass-sculpture/sculpture.wgsl. Upstream branches retained; Hyalos additions marked.
struct SculptureParams {
  resolution: vec2f,
  orb_enabled: f32,
  orb_mode: f32,
  orb_mapping: f32,
  orb_strength: f32,
  orb_scale: f32,
  shape: f32,
  tint: f32,
  time: f32,
  quality: f32,
  yaw: f32,
  pitch: f32,
  radius: f32,
  focal_length: f32,
  custom_tint: vec4f,
  atmosphere_color: vec4f,
  reflection_color: vec4f,
  dispersion: f32,
  roughness: f32,
  edge_softness: f32,
  sample_count: f32,
  floor_enabled: f32,
  strip_angle: f32,
  floor_luminance: f32,
  metalness: f32,
  atmosphere: f32,
  visible_lights: f32,
  tile_origin: vec2f,
  tile_size: vec2f,
  key: vec4f,
  key_color: vec4f,
  rim: vec4f,
  rim_color: vec4f,
  background_top: vec4f,
  background_bottom: vec4f,
}

@group(0) @binding(0) var<uniform> params: SculptureParams;
@group(0) @binding(1) var orb_texture: texture_2d<f32>;
@group(0) @binding(2) var orb_sampler: sampler;

const FLOOR_HEIGHT: f32 = -1.05;
const GLASS_IOR: f32 = 1.5;
const HIT_EPSILON: f32 = 0.00015;

fn rotate2(angle: f32) -> mat2x2f {
  let c = cos(angle);
  let s = sin(angle);
  return mat2x2f(c, s, -s, c);
}

fn smooth_union(a: f32, b: f32, radius: f32) -> f32 {
  let blend = clamp(0.5 + 0.5 * (b - a) / radius, 0.0, 1.0);
  return mix(b, a, blend) - radius * blend * (1.0 - blend);
}

fn smooth_intersection(a: f32, b: f32, radius: f32) -> f32 {
  return -smooth_union(-a,-b,radius);
}

fn torus_distance(point: vec3f, radii: vec2f) -> f32 {
  return length(vec2f(length(point.xz) - radii.x, point.y)) - radii.y;
}

fn rounded_box_distance(point: vec3f, bounds: vec3f, radius: f32) -> f32 {
  let delta = abs(point) - bounds;
  return length(max(delta, vec3f(0.0))) + min(max(delta.x, max(delta.y, delta.z)), 0.0) - radius;
}

// Asymptote: a turning tower and a ribbed dome, each surrendering pieces toward one point.
const ASYMPTOTE_MEET: vec3f = vec3f(0.06, 0.5, 0.1);

fn tower_distance(q: vec3f) -> f32 {
  let t = q - vec3f(-0.85, 0.0, 0.0);
  var d = max(length(t.xz) - 0.05, abs(t.y + 0.08) - 0.93);
  d = min(d, rounded_box_distance(t - vec3f(0.0, -1.0, 0.0), vec3f(0.34, 0.022, 0.34), 0.008));
  // Nine remaining floors, each turned 0.2 rad; the cantilever toward the dome grows by 1.45 per floor.
  for (var i = 0; i < 9; i += 1) {
    let f = f32(i);
    let offset = t - vec3f(0.006 * pow(1.45, f), -0.92 + f * 0.15, 0.0);
    let turned = rotate2(f * 0.2) * offset.xz;
    d = min(d, rounded_box_distance(vec3f(turned.x, offset.y, turned.y), vec3f(0.23, 0.012, 0.23), 0.008));
  }
  return d;
}

fn dome_distance(q: vec3f) -> f32 {
  let u = q - vec3f(0.7, -0.98, 0.0);
  let radius = 0.62;
  var d = torus_distance(u, vec2f(radius, 0.024));
  d = min(d, torus_distance(u - vec3f(0.0, 0.606, 0.0), vec2f(0.13, 0.02)));
  d = min(d, max(length(u.xz) - radius - 0.08, abs(u.y + 0.045) - 0.022));
  // Ten meridian ribs; the two facing the tower have left.
  for (var j = 0; j < 10; j += 1) {
    let azimuth = f32(j) * 0.6283185 + 0.3141593;
    if (cos(azimuth) < -0.7) { continue; }
    let across = vec2f(cos(azimuth), sin(azimuth));
    let radial = dot(u.xz, across);
    let normal = dot(u.xz, vec2f(-across.y, across.x));
    let angle = clamp(atan2(u.y, radial), 0.0, 1.3589);
    d = min(d, length(vec3f(radial - radius * cos(angle), u.y - radius * sin(angle), normal)) - 0.022);
  }
  return d;
}

// Zeno's series: every piece covers 60% of the remaining way and shrinks; the two never touch.
fn envoy_distance(q: vec3f) -> f32 {
  var d = 100.0;
  let floors = vec3f(-0.79, 0.62, 0.0) - ASYMPTOTE_MEET;
  let ribs = vec3f(0.19, -0.63, 0.0) - ASYMPTOTE_MEET;
  let axis = -normalize(ribs);
  for (var k = 0; k < 6; k += 1) {
    let f = f32(k);
    let reach = 0.78 * pow(0.6, f);
    let size = 0.22 * pow(0.7, f + 1.0);
    let floor_point = q - ASYMPTOTE_MEET - floors * reach;
    let turned = rotate2((9.0 + f) * 0.2) * floor_point.xz;
    let tumbled = vec3f(rotate2(f * 0.22) * vec2f(turned.x, floor_point.y), turned.y);
    d = min(d, rounded_box_distance(tumbled, vec3f(size, size * 0.055 + 0.004, size), 0.006));
    let ring_point = q - ASYMPTOTE_MEET - ribs * reach;
    let along = dot(ring_point, axis);
    let ring = length(vec2f(length(ring_point - axis * along) - 0.15 * pow(0.72, f), along));
    d = min(d, ring - max(0.018 * pow(0.72, f), 0.005));
  }
  return d;
}

// Hyalos extensions. Closed, smooth distance fields avoid detached foil fragments.
fn hyalos_distance(world: vec3f, mode: i32) -> f32 {
  let turn = rotate2(params.time * 0.25) * world.xz;
  let p = vec3f(turn.x, world.y, turn.y);
  if (mode == 3) {
    // Rounded crescent carved from a continuous curved shell.
    let q = vec3f(rotate2(0.5)*p.xy,p.z);
    let crescent = smooth_intersection(length(q.xy)-0.95,-(length(q.xy-vec2f(-0.34,0.24))-0.86),params.edge_softness);
    let bevel = vec2f(crescent,abs(q.z)-0.13);
    return length(max(bevel,vec2f(0.0)))+min(max(bevel.x,bevel.y),0.0)-0.055;
  }
  if (mode == 4) {
    // Continuous rings and polished pearls, smoothly fused rather than cut foil.
    let a = vec3f(p.x, p.y*0.76, p.z);
    let b = vec3f(rotate2(0.65)*a.xy,a.z);
    let c = vec3f(rotate2(-0.65)*a.xy,a.z);
    var d = min(torus_distance(b.xzy,vec2f(0.78,0.11)),torus_distance(c.zyx,vec2f(0.78,0.11)));
    d = smooth_union(d,length(p-vec3f(-0.23,0.56,0.1))-0.35,0.1);
    d = smooth_union(d,length(p-vec3f(0.18,-0.51,-0.04))-0.39,0.12);
    return d*0.76;
  }
  if (mode == 5) {
    // A (2,3) torus knot; both polar branches make a seamless closed trefoil.
    let angle = atan2(p.z,p.x);
    var d = 100.0;
    for(var i=0;i<2;i+=1) {
      let phase = 1.5*angle+f32(i)*3.14159265;
      let center = vec2f(0.7+0.26*cos(phase),0.26*sin(phase));
      d = min(d,length(vec2f(length(p.xz),p.y)-center)-0.15);
    }
    return d*0.58;
  }
  if (mode == 6) {
    let angle = atan2(p.z,p.x);
    let cross_section = rotate2(angle*0.5)*vec2f(length(p.xz)-0.75,p.y);
    return rounded_box_distance(vec3f(cross_section,0.0),vec3f(0.3,0.065,0.0),0.065)*0.64;
  }
  if (mode == 7) {
    let q = p*4.8;
    let schwarz = (cos(q.x)+cos(q.y)+cos(q.z))/8.32;
    return smooth_intersection(length(p)-1.03,abs(schwarz)-0.055,params.edge_softness);
  }
  if (mode == 9) {
    let angle=atan2(p.z,p.x);
    let cross_section=vec2f(length(p.xz)-0.68,p.y+0.12*sin(angle*3.0));
    return (length(cross_section)-0.27)*0.72;
  }
  if (mode == 10) {
    let phase=p.y*3.7;
    let center=vec2f(cos(phase),sin(phase))*0.53;
    let helix=min(length(p.xz-center),length(p.xz+center))-0.19;
    return smooth_intersection(helix,abs(p.y)-1.0,params.edge_softness)*0.36;
  }
  if (mode == 11) {
    let angle=atan2(p.z,p.x);
    let cross_section=rotate2(angle*2.0)*vec2f(length(p.xz)-0.86,p.y+0.15*sin(angle*3.0));
    return rounded_box_distance(vec3f(cross_section,0.0),vec3f(0.27,0.055,0.0),0.075)*0.46;
  }
  if (mode == 12) {
    let octahedron=(abs(p.x)+abs(p.y)+abs(p.z)-1.45)*0.57735027-0.08;
    let holes=min(length(p.xy),min(length(p.xz),length(p.yz)))-0.24;
    return smooth_intersection(octahedron,-holes,params.edge_softness);
  }
  if (mode == 13) {
    var cluster=100.0;
    for(var i=0;i<7;i+=1) {
      let fi=f32(i);
      let center=vec3f(sin(fi*2.39996)*0.44,(fi-3.0)*0.21,cos(fi*2.39996)*0.44);
      cluster=smooth_union(cluster,length(p-center)-(0.33+0.05*sin(fi*1.4)),0.2);
    }
    return cluster;
  }
  if (mode == 14) {
    let waves=sin(p.x*4.4+p.y)*cos(p.y*3.8-p.z)*0.09+sin(p.z*5.2+p.x)*0.055;
    return (length(p*vec3f(1.0,0.85,1.0))-0.88+waves)*0.5;
  }
  if (mode == 15) {
    let s = 0.82;
    // Face the default camera (yaw 0.9) so the pair reads side by side.
    let front = rotate2(0.9) * p.xz;
    let q = vec3f(front.x, p.y, front.y) / s;
    let bound = length(q - vec3f(0.2, -0.1, 0.0)) - 1.45;
    if (bound > 0.3) { return bound * s; }
    return min(min(tower_distance(q), dome_distance(q)), envoy_distance(q)) * s * 0.9;
  }
  // Three interwoven organic petals with a continuous polished surface.
  let a = torus_distance(p,vec2f(0.72,0.13));
  let b = torus_distance(vec3f(p.x,rotate2(1.0472)*p.yz),vec2f(0.72,0.13));
  let c = torus_distance(vec3f(p.x,rotate2(-1.0472)*p.yz),vec2f(0.72,0.13));
  return smooth_union(smooth_union(a,b,0.12),c,0.12);
}

fn sculpture_distance(world_point: vec3f) -> f32 {
  if (params.shape >= 3.0) { return hyalos_distance(world_point, i32(params.shape + 0.5)); }
  let rotated = rotate2(params.time * 0.25) * world_point.xz;
  let point = vec3f(rotated.x, world_point.y, rotated.y);
  let mode = i32(params.shape + 0.5);

  if (mode == 1) {
    let frequency = 5.0;
    let gyroid = (
      sin(point.x * frequency) * cos(point.y * frequency) +
      sin(point.y * frequency) * cos(point.z * frequency) +
      sin(point.z * frequency) * cos(point.x * frequency)
    ) / frequency;
    return smooth_intersection(length(point) - 1.0, abs(gyroid) - 0.07, params.edge_softness) * 0.55;
  }

  if (mode == 2) {
    var distance = 100000.0;
    for (var i = 0; i < 6; i += 1) {
      let index = f32(i);
      let center = vec3f(
        sin(params.time * 0.7 + index * 2.1),
        cos(params.time * 0.5 + index * 1.3) * 0.6,
        sin(params.time * 0.6 + index * 0.7 + 1.0)
      ) * 0.55;
      let radius = 0.42 + sin(index * 3.0 + params.time) * 0.1;
      distance = smooth_union(distance, length(point - center) - radius, 0.35);
    }
    return distance;
  }

  let angle = atan2(point.z, point.x);
  let cross_section = rotate2(angle * 1.5 + params.time * 0.5) * vec2f(length(point.xz) - 0.75, point.y);
  let ribbon = rounded_box_distance(vec3f(cross_section, 0.0), vec3f(0.34, 0.12, 0.0), 0.08);
  let ring = torus_distance(point, vec2f(1.05, 0.06));
  // Angular warping is not a unit-gradient SDF. A conservative bound avoids stepping through folds.
  return smooth_union(ribbon, ring, 0.15) * 0.4;
}

fn sculpture_normal(point: vec3f) -> vec3f {
  let epsilon = 0.00035;
  let axis = vec2f(1.0, -1.0);
  return normalize(
    axis.xyy * sculpture_distance(point + axis.xyy * epsilon) +
    axis.yyx * sculpture_distance(point + axis.yyx * epsilon) +
    axis.yxy * sculpture_distance(point + axis.yxy * epsilon) +
    axis.xxx * sculpture_distance(point + axis.xxx * epsilon)
  );
}

fn march_surface(origin: vec3f, direction: vec3f, distance_sign: f32, limit: f32, step_limit: i32) -> f32 {
  var travel = 0.0;
  var previous = 0.0;
  for (var step_index = 0; step_index < 256; step_index += 1) {
    if (step_index >= step_limit) { break; }
    let distance = sculpture_distance(origin + direction * travel) * distance_sign;
    if (distance < HIT_EPSILON) {
      // Refine crossed surfaces rather than shading an overshot point inside the object.
      if (distance < 0.0 && travel > previous) {
        var low = previous;
        var high = travel;
        for (var refinement = 0; refinement < 10; refinement += 1) {
          let middle = (low + high) * 0.5;
          if (sculpture_distance(origin + direction * middle) * distance_sign > 0.0) { low = middle; } else { high = middle; }
        }
        return (low + high) * 0.5;
      }
      return travel;
    }
    previous = travel;
    travel += distance * 0.8;
    if (travel > limit) { break; }
  }
  return -1.0;
}

fn fresnel_schlick(cosine: f32) -> f32 {
  return 0.04 + 0.96 * pow(clamp(1.0 - cosine, 0.0, 1.0), 5.0);
}

fn softbox(direction: vec3f, light_direction: vec3f, hardness: f32, power: f32) -> f32 {
  return pow(clamp(dot(direction, light_direction), 0.0, 1.0), hardness) * power;
}

// Asymptote's void: deterministic spheres at finite depth, with parallax and haze.
// Each sphere uses the sculpture's glass: Fresnel reflection, two-interface refraction, tint absorption, metalness.
fn void_spheres(origin: vec3f, direction: vec3f, backdrop: vec3f) -> vec3f {
  if (i32(params.shape + 0.5) != 15) { return backdrop; }
  var nearest = 1e9;
  var color = backdrop;
  let tint = absorption_color();
  let tinted = step(0.01, length(tint));
  for (var i = 0; i < 88; i += 1) {
    let seed = f32(i) + 1.0;
    let h = fract(sin(vec3f(seed * 12.9898, seed * 78.233, seed * 37.719)) * 43758.5453);
    let g = fract(sin(vec3f(seed * 93.989, seed * 67.345, seed * 21.437)) * 24634.6345);
    let axis = normalize(h * 2.0 - 1.0 + vec3f(0.0, 0.0001, 0.0));
    let center = axis * (11.0 + 28.0 * g.x * g.x);
    let radius = 0.08 + 0.75 * g.y * g.y * g.y;
    let oc = origin - center;
    let b = dot(oc, direction);
    let h2 = b * b - dot(oc, oc) + radius * radius;
    if (h2 <= 0.0) { continue; }
    let t = -b - sqrt(h2);
    if (t <= 0.0 || t >= nearest) { continue; }
    nearest = t;
    let n = normalize(oc + direction * t);
    let reflected = studio_sky(reflect(direction, n));
    let inside = refract(direction, n, 1.0 / GLASS_IOR);
    // A chord through a sphere leaves at distance -2 R (inside · n).
    let chord = -2.0 * radius * dot(inside, n);
    let exit_normal = normalize(oc + direction * t + inside * chord);
    var outward = refract(inside, -exit_normal, GLASS_IOR);
    if (dot(outward, outward) < 0.5) { outward = reflect(inside, -exit_normal); }
    let transmitted = studio_sky(outward) * exp(-(vec3f(1.0) - tint) * chord * params.custom_tint.w * tinted);
    var glass = mix(transmitted, reflected, fresnel_schlick(dot(-direction, n)));
    glass = mix(glass, reflected * mix(vec3f(1.0), tint, tinted * 0.3), params.metalness);
    color = mix(glass, backdrop, 1.0 - exp(-max(t - 8.0, 0.0) * 0.06));
  }
  return color;
}

fn studio_radiance(direction: vec3f) -> vec3f {
  return studio_radiance_from(vec3f(0.0), direction);
}

fn studio_radiance_from(origin: vec3f, direction: vec3f) -> vec3f {
  return void_spheres(origin, direction, studio_sky(direction));
}

fn studio_sky(direction: vec3f) -> vec3f {
  let sky_mix = pow(clamp(direction.y * 0.5 + 0.5, 0.0, 1.0), 1.5);
  var color = mix(params.background_bottom.rgb, params.background_top.rgb, sky_mix) * params.atmosphere_color.w;
  color += params.key_color.rgb * softbox(direction, normalize(params.key.xyz), 24.0, params.key.w);
  color += params.rim_color.rgb * softbox(direction, normalize(params.rim.xyz), 40.0, params.rim.w);
  color += params.background_top.rgb * softbox(direction, vec3f(0.0, 1.0, 0.0), 6.0, 0.6);
  let strip_axis = vec2f(cos(params.strip_angle), sin(params.strip_angle));
  let strip_horizontal = abs(dot(direction.xz, strip_axis));
  let strip = smoothstep(0.985, 1.0, strip_horizontal) * smoothstep(0.35, 0.0, abs(direction.y - 0.1));
  color += params.reflection_color.rgb * params.reflection_color.w * strip * 3.0 * clamp(params.key.w / 6.0, 0.3, 1.5);
  if (params.atmosphere > 0.0) {
    // Broad cold reflection cards reveal the folds against a dark environment.
    let band = exp(-pow((direction.x + direction.y * 0.52 - 0.12) / 0.17, 2.0));
    let cut = smoothstep(-0.5, 0.0, direction.z);
    color += params.reflection_color.rgb * params.reflection_color.w * band * cut * 4.0 * params.atmosphere;
    color += params.reflection_color.rgb * params.reflection_color.w * pow(max(0.0,dot(direction,normalize(vec3f(-0.6,0.75,-0.25)))),16.0)*3.0*params.atmosphere;
  }
  return color;
}

// Lighting cards illuminate/refelect in the sculpture, but need not appear as floating discs in the background.
// A compact angular filter gives rough reflections a continuous highlight footprint.
fn reflection_radiance(direction: vec3f) -> vec3f {
  if(params.roughness < 0.005) { return studio_radiance(direction); }
  let axis=select(vec3f(0.0,1.0,0.0),vec3f(1.0,0.0,0.0),abs(direction.y)>0.95);
  let tangent=normalize(cross(direction,axis));
  let bitangent=cross(direction,tangent);
  let radius=params.roughness*params.roughness*0.75;
  return studio_radiance(direction)*0.4 + 0.15*(
    studio_radiance(normalize(direction+tangent*radius))+
    studio_radiance(normalize(direction-tangent*radius))+
    studio_radiance(normalize(direction+bitangent*radius))+
    studio_radiance(normalize(direction-bitangent*radius)));
}
fn background_radiance(origin: vec3f, direction: vec3f) -> vec3f {
  let sky_mix = pow(clamp(direction.y*0.5+0.5,0.0,1.0),1.5);
  return void_spheres(origin, direction, mix(params.background_bottom.rgb,params.background_top.rgb,sky_mix) * params.atmosphere_color.w);
}
fn absorption_color() -> vec3f {
  let mode = i32(params.tint + 0.5);
  if (mode == 1) { return vec3f(0.95, 0.45, 0.60); }
  if (mode == 2) { return vec3f(0.35, 0.55, 0.95); }
  if (mode == 3) { return vec3f(0.50, 0.90, 0.65); }
  if (mode == 4) { return vec3f(1.0,0.64,0.2); }
  if (mode == 5) { return vec3f(0.68,0.38,0.95); }
  if (mode == 6) { return vec3f(0.48,0.85,1.0); }
  if (mode == 7) { return vec3f(0.22,0.24,0.28); }
  if (mode == 8) { return params.custom_tint.rgb; }
  return vec3f(0.0);
}

fn shade_floor(point: vec3f, incoming: vec3f) -> vec3f {
  let radius = length(point.xz);
  var color = params.background_bottom.rgb * params.atmosphere_color.w * params.floor_luminance * (1.0 + 0.25 * smoothstep(3.5, 0.0, radius));
  color += studio_radiance(reflect(incoming, vec3f(0.0, 1.0, 0.0))) * fresnel_schlick(-incoming.y) * 0.5;
  color *= 1.0 - 0.45 * smoothstep(1.5, 0.3, radius);
  let key_direction = normalize(params.key.xyz);
  let caustic_position = point.xz + key_direction.xz * 0.55;
  let caustic = pow(smoothstep(0.9, 0.0, length(caustic_position)), 3.0);
  let pulse = 0.6 + 0.4 * sin(params.time * 1.3);
  color += params.key_color.rgb * caustic * pulse * 0.35 * clamp(params.key.w / 6.0, 0.2, 1.5);
  return color;
}

fn trace_glass(origin: vec3f, direction: vec3f, hit_distance: f32, ior: f32) -> vec3f {
  var position = origin + direction * hit_distance;
  let entry_normal = sculpture_normal(position);
  var ray = refract(direction, entry_normal, 1.0 / ior);
  position -= entry_normal * 0.001;
  var radiance = vec3f(0.0);
  var throughput = 1.0;
  var internal_distance = 0.0;

  for (var bounce = 0; bounce < 3; bounce += 1) {
    let start = position + ray * 0.0002;
    let exit_distance = march_surface(start, ray, -1.0, 6.0, 160);
    if (exit_distance < 0.0) {
      radiance += studio_radiance(ray) * throughput;
      throughput = 0.0;
      break;
    }

    internal_distance += exit_distance;
    position = start + ray * exit_distance;
    let inward_normal = -sculpture_normal(position);
    let exit_ray = refract(ray, inward_normal, ior);
    if (dot(exit_ray, exit_ray) < 0.5) {
      ray = reflect(ray, inward_normal);
      position += inward_normal * 0.001;
      continue;
    }

    let reflection = fresnel_schlick(dot(-ray, inward_normal));
    var outside = reflection_radiance(exit_ray);
    if (exit_ray.y < 0.0 && params.floor_enabled > 0.5) {
      let floor_distance = (FLOOR_HEIGHT - position.y) / exit_ray.y;
      let floor_point = position + exit_ray * floor_distance;
      outside = mix(shade_floor(floor_point, exit_ray), outside, smoothstep(2.5, 6.0, length(floor_point.xz)));
    }
    radiance += outside * (1.0 - reflection) * throughput;
    throughput *= reflection;
    ray = reflect(ray, inward_normal);
    position += inward_normal * 0.001;
    if (throughput < 0.05) { break; }
  }

  radiance += studio_radiance(ray) * throughput;
  let tint = absorption_color();
  let absorption = exp(-(vec3f(1.0) - tint) * internal_distance * params.custom_tint.w * step(0.01, length(tint)));
  return radiance * absorption;
}

// The original orb is an animated GPU material. Projection does not replace geometry.
fn orb_linear(uv: vec2f) -> vec3f {
  let color=textureSampleLevel(orb_texture,orb_sampler,clamp(uv,vec2f(0.01),vec2f(0.99)),0.0).rgb;
  return pow(clamp(color,vec3f(0.0),vec3f(16.0)),vec3f(2.2));
}
fn orb_color(point: vec3f,normal: vec3f,uv:vec2f) -> vec3f {
  if(params.orb_mapping>1.5) {return orb_linear((uv-0.5)*params.orb_scale+0.5);}
  if(params.orb_mapping>0.5) {return orb_linear(normal.xy*0.42*params.orb_scale+0.5);}
  let spun=rotate2(params.time*0.25)*point.xz;
  let p=vec3f(spun.x,point.y,spun.y)*params.orb_scale;
  let n=abs(normal);
  let weight=pow(n,vec3f(4.0));
  return (orb_linear(p.yz*0.3+0.5)*weight.x+orb_linear(p.xz*0.3+0.5)*weight.y+orb_linear(p.xy*0.3+0.5)*weight.z)/max(dot(weight,vec3f(1.0)),0.001);
}

fn shade_sample(global_uv: vec2f) -> vec3f {
  let aspect = params.resolution.x / max(params.resolution.y, 1.0);
  var screen = (global_uv - 0.5) * 2.0;
  screen = vec2f(screen.x * aspect, -screen.y);

  let camera_position = vec3f(
    params.radius * sin(params.yaw) * cos(params.pitch),
    params.radius * sin(params.pitch) + 0.1,
    params.radius * cos(params.yaw) * cos(params.pitch)
  );
  let forward = normalize(vec3f(0.0, -0.05, 0.0) - camera_position);
  let right = normalize(cross(forward, vec3f(0.0, 1.0, 0.0)));
  let up = cross(right, forward);
  let ray = normalize(screen.x * right + screen.y * up + params.focal_length * forward);

  let surface_steps = i32(mix(160.0, 256.0, params.quality));
  let sculpture_hit = march_surface(camera_position, ray, 1.0, 12.0, surface_steps);
  let floor_hit = select(-1.0, (FLOOR_HEIGHT - camera_position.y) / ray.y, ray.y < 0.0 && params.floor_enabled > 0.5);
  var color: vec3f;

  if (sculpture_hit > 0.0 && (floor_hit < 0.0 || sculpture_hit < floor_hit)) {
    let point = camera_position + ray * sculpture_hit;
    let normal = sculpture_normal(point);
    let reflection_weight = fresnel_schlick(-dot(ray, normal));
    let reflected = reflection_radiance(reflect(ray, normal));
    let spread = params.dispersion;
    var refracted = reflected;
    if (params.metalness >= 0.9999) {
      // Opaque silver has no transmitted ray; avoid undefined refraction at grazing angles.
    } else if (spread > 0.001) {
      refracted = vec3f(
        trace_glass(camera_position, ray, sculpture_hit, GLASS_IOR - spread).r,
        trace_glass(camera_position, ray, sculpture_hit, GLASS_IOR).g,
        trace_glass(camera_position, ray, sculpture_hit, GLASS_IOR + spread).b
      );
    } else {
      refracted = trace_glass(camera_position, ray, sculpture_hit, GLASS_IOR);
    }
    color = mix(refracted, reflected, reflection_weight);
    color = mix(color, reflected * mix(vec3f(1.0),absorption_color(),step(0.01,length(absorption_color()))*0.3),params.metalness);
    if(params.orb_enabled>0.5 && params.orb_strength>0.0001) {
      let pigment=orb_color(point,normal,global_uv);
      if(params.orb_mode<0.5) {
        let diffuse=0.16+max(dot(normal,normalize(params.key.xyz)),0.0)*params.key.w*0.16+max(dot(normal,normalize(params.rim.xyz)),0.0)*params.rim.w*0.12;
        let dye=mix(vec3f(1.0),absorption_color(),step(0.01,length(absorption_color()))*clamp(params.custom_tint.w*0.45,0.0,1.0));
        let coated=pigment*dye*diffuse*(1.0-params.metalness)+reflected*mix(reflection_weight,1.0,params.metalness);
        color=mix(color,coated*max(1.0,params.orb_strength),clamp(params.orb_strength,0.0,1.0));
      } else if(params.orb_mode<1.5) {
        color+=pigment*params.orb_strength*2.0;
      } else {
        let reflection=reflect(ray,normal);
        let environment=orb_linear(reflection.xy*0.44+0.5);
        color=mix(color,environment*(0.3+0.7*reflection_weight)*max(1.0,params.orb_strength),clamp(params.orb_strength,0.0,1.0));
      }
    }
    // The environment already reflects the softboxes. Do not add duplicate Phong spots.
  } else if (floor_hit > 0.0) {
    let floor_point = camera_position + ray * floor_hit;
    let reflected_ray = reflect(ray, vec3f(0.0, 1.0, 0.0));
    let reflection_hit = march_surface(floor_point + vec3f(0.0, 0.002, 0.0), reflected_ray, 1.0, 8.0, 70);
    var floor_color = shade_floor(floor_point, ray);
    if (reflection_hit > 0.0) {
      let reflection_point = floor_point + reflected_ray * reflection_hit;
      let reflection_normal = sculpture_normal(reflection_point);
      let reflection_weight = fresnel_schlick(-dot(reflected_ray, reflection_normal));
      let ghost = mix(
        studio_radiance(refract(reflected_ray, reflection_normal, 1.0 / GLASS_IOR)) * 0.6,
        studio_radiance(reflect(reflected_ray, reflection_normal)),
        reflection_weight
      );
      floor_color = mix(floor_color, ghost, clamp(fresnel_schlick(-ray.y) * 1.5, 0.0, 0.85));
    }
    color = mix(floor_color, select(background_radiance(camera_position,ray),studio_radiance_from(camera_position,ray),params.visible_lights>0.5), smoothstep(3.0, 8.0, length(floor_point.xz)));
  } else {
    color = select(background_radiance(camera_position,ray),studio_radiance_from(camera_position,ray),params.visible_lights>0.5);
    if (params.atmosphere > 0.0) {
      color = mix(color,mix(params.background_bottom.rgb,params.background_top.rgb,global_uv.y)*0.3*params.atmosphere_color.w,params.atmosphere);
      let beam = exp(-pow((screen.x-screen.y*0.7-0.22)/0.3,2.0));
      color += params.atmosphere_color.rgb*beam*params.atmosphere;
    }
  }

  // Bound radiance before half-float storage and bloom to prevent overflow blocks.
  return clamp(color, vec3f(0.0), vec3f(128.0));
}

// Fixed spatial samples: no temporal ghosting, shared by live preview and tiled export.
@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let pixel=params.tile_origin+uv*params.tile_size;
  if(params.sample_count<2.0) {return vec4f(shade_sample(pixel/params.resolution),1.0);}
  let offsets=array<vec2f,4>(vec2f(-0.375,-0.125),vec2f(0.125,-0.375),vec2f(0.375,0.125),vec2f(-0.125,0.375));
  var color=vec3f(0.0);
  for(var i=0;i<4;i+=1){color+=shade_sample((pixel+offsets[i])/params.resolution);}
  return vec4f(color*0.25,1.0);
}
