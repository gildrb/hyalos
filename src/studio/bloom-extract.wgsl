// Hyalos soft-knee bloom prefilter. The verified upstream shader remains untouched.
struct BloomExtractParams { texel: vec2f, threshold: f32, knee: f32 }
@group(0) @binding(0) var<uniform> params: BloomExtractParams;
@group(0) @binding(1) var source: texture_2d<f32>;
@group(0) @binding(2) var linear_sampler: sampler;
@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  var color=vec3f(0.0);
  var total=0.0;
  // Tent downsample with luminance weighting suppresses isolated subpixel fireflies.
  for(var y=-1;y<=1;y+=1){
    for(var x=-1;x<=1;x+=1){
      let c=textureSampleLevel(source,linear_sampler,uv+vec2f(f32(x),f32(y))*params.texel*1.5,0.0).rgb;
      let spatial=select(1.0,2.0,x==0)*select(1.0,2.0,y==0);
      let weight=spatial/(1.0+dot(c,vec3f(0.2126,0.7152,0.0722))*0.06);
      color+=c*weight; total+=weight;
    }
  }
  color/=total;
  let brightness=max(color.r,max(color.g,color.b));
  let knee=max(0.0001,params.threshold*params.knee);
  var soft=clamp(brightness-params.threshold+knee,0.0,2.0*knee);
  soft=soft*soft/(4.0*knee+0.0001);
  let contribution=max(soft,brightness-params.threshold)/max(brightness,0.0001);
  return vec4f(color*contribution,1.0);
}
