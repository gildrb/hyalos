// Derived from glass-sculpture/present.wgsl; additional finish only for Hyalos compositions.
struct PresentParams {
  bloom_strength: f32,
  time: f32,
  grain: f32,
  texture: f32,
  coolness: f32,
  exposure: f32,
  vignette: f32,
  antialias: f32,
  grade_color: vec4f,
  full_size: vec2f,
  tile_origin: vec2f,
  tile_size: vec2f,
}

@group(0) @binding(0) var<uniform> params: PresentParams;
@group(0) @binding(1) var scene_texture: texture_2d<f32>;
@group(0) @binding(2) var bloom_texture: texture_2d<f32>;
@group(0) @binding(3) var linear_sampler: sampler;
@group(0) @binding(4) var bloom_wide: texture_2d<f32>;

fn aces(color: vec3f) -> vec3f {
  return (color * (2.51 * color + 0.03)) / (color * (2.43 * color + 0.59) + 0.14);
}

// Edge-aware antialiasing filters the ray-marched silhouette before finishing.
fn sample_scene(uv: vec2f) -> vec3f {
  return textureSampleLevel(scene_texture,linear_sampler,uv,0.0).rgb;
}
fn luma(c: vec3f) -> f32 { return dot(aces(c),vec3f(0.299,0.587,0.114)); }
fn filtered_scene(uv: vec2f) -> vec3f {
  let center = sample_scene(uv);
  if (params.antialias < 0.5) { return center; }
  let px = 1.0/vec2f(textureDimensions(scene_texture));
  let nw=luma(sample_scene(uv+px*vec2f(-1.0,-1.0)));
  let ne=luma(sample_scene(uv+px*vec2f(1.0,-1.0)));
  let sw=luma(sample_scene(uv+px*vec2f(-1.0,1.0)));
  let se=luma(sample_scene(uv+px*vec2f(1.0,1.0)));
  let lc=luma(center);
  let low=min(lc,min(min(nw,ne),min(sw,se)));
  let high=max(lc,max(max(nw,ne),max(sw,se)));
  if (high-low < max(0.04,high*0.12)) { return center; }
  var dir=vec2f(-(nw+ne-sw-se),nw+sw-ne-se);
  let reduction=max((nw+ne+sw+se)*0.03125,0.0078125);
  dir=clamp(dir/(min(abs(dir.x),abs(dir.y))+reduction),vec2f(-4.0),vec2f(4.0))*px;
  let a=(sample_scene(uv-dir/6.0)+sample_scene(uv+dir/6.0))*0.5;
  let b=a*0.5+(sample_scene(uv-dir*0.5)+sample_scene(uv+dir*0.5))*0.25;
  let lb=luma(b);
  return select(b,a,lb<low || lb>high);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let scene = filtered_scene(uv);
  let global_uv = (params.tile_origin+uv*params.tile_size)/params.full_size;
  let bloom = textureSampleLevel(bloom_texture, linear_sampler, uv, 0.0).rgb*0.65 + textureSampleLevel(bloom_wide,linear_sampler,uv,0.0).rgb*0.35;
  var color = aces((scene + bloom * params.bloom_strength) * params.exposure);
  let centered = global_uv - 0.5;
  color *= 1.0 - dot(centered, centered) * params.vignette;
  let noise = fract(sin(dot(global_uv * 1000.0 + params.time, vec2f(12.9898, 78.233))) * 43758.5453) - 0.5;
  color += noise * params.grain;
  let scan = 0.5+0.5*cos(global_uv.x*params.full_size.x*3.14159265);
  color *= 1.0-scan*params.texture*0.08;
  let silver = mix(vec3f(dot(color,vec3f(0.2126,0.7152,0.0722))),color,0.62)*params.grade_color.rgb;
  color = mix(color,silver,params.coolness);
  return vec4f(pow(clamp(color, vec3f(0.0), vec3f(1.0)), vec3f(1.0 / 1.05)), 1.0);
}
