@group(0) @binding(1) var sceneTex: texture_2d<f32>;
@group(0) @binding(2) var linearSampler: sampler;
fn sampleScene(global: vec2f) -> vec3f {
  let point = clamp(global,vec2f(0.5),u.view.xy-0.5);
  let uv = (point-u.tile.xy)/u.tile.zw;
  return textureSampleLevel(sceneTex,linearSampler,uv,0.0).rgb;
}
fn optical(global: vec2f) -> vec3f {
  let base = sampleScene(global);
  if (u.energy.w == 0.0) { return base; }
  var scatter = vec3f(0.0);
  let radius = u.finish.z*u.view.y/1080.0;
  // Finite, normalised point-spread kernel. Redistributes, rather than invents, light.
  var weight = 0.0;
  for (var ring = 1; ring <= 3; ring++) {
    let r = f32(ring); let w = exp(-r*r*0.5);
    for (var i = 0; i < 8; i++) {
      let a = f32(i)*TAU/8.0;
      scatter += sampleScene(global+vec2f(cos(a),sin(a))*radius*r)*w;
      weight += w;
    }
  }
  let scattered = scatter/max(weight,0.0001);
  return mix(base,scattered,u.energy.w);
}
@fragment fn fs_main(@builtin(position) pixel: vec4f) -> @location(0) vec4f {
  let global = pixel.xy+u.tile.xy;
  let scale = u.view.y/1080.0;
  var col = tone(optical(global));
  let background = tone(u.background.rgb);
  let ink = tone(u.energy.rgb*3.0);
  if (u.style.x > 0.5 && u.style.x < 1.5) {
    let cell = u.style.y*scale;
    let center = (floor(global/cell)+0.5)*cell;
    let intensity = clamp(luminance(tone(optical(center)))*2.0,0.0,1.0);
    let radius = cell*u.style.z*sqrt(intensity);
    let distance = length(global-center);
    let cover = 1.0-smoothstep(radius-0.65,radius+0.65,distance);
    col = mix(background,ink,cover*step(0.025,intensity));
  } else if (u.style.x > 1.5 && u.style.x < 2.5) {
    let cell = max(1.0,u.style.y*scale*0.25);
    let pp = vec2u(floor(global/cell));
    let value = dither8(pp,clamp(luminance(col)*1.7,0.0,1.0));
    col = mix(col,mix(background,ink,value),u.style.w);
  } else if (u.style.x > 2.5) {
    // Suppress scan frequencies above the pixel Nyquist limit, not visible moiré.
    let frequency = PI/max(scale,0.2);
    let resolved = 1.0-smoothstep(PI*0.5,PI,frequency);
    let scan = 0.83+0.17*resolved*cos(global.y*frequency);
    col *= scan;
  }
  // Camera vignetting, then display transform. Grain is an explicit graphic finish.
  let position = (global-u.view.xy*0.5)/u.view.y;
  col *= max(0.0,1.0-u.finish.y*dot(position,position)*0.8);
  col = pow(max(col,vec3f(0.0)),vec3f(u.metal.w));
  var display = srgb(col);
  let integer = vec2u(global);
  let noise = rand(integer.x+integer.y*65537u+u32(u.view.w)*1597u)-0.5;
  display += noise*u.finish.x;
  return vec4f(clamp(display,vec3f(0.0),vec3f(1.0)),1.0);
}
