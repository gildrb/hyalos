// Original scene and light-transport code. MIT, 2026 Exo Visuals contributors.
// Artist-authored SDF geometry, not a fluid or rigid-body simulation.
struct Sample { d: f32, material: f32 };
fn nearer(a: Sample, b: Sample) -> Sample { if (a.d < b.d) { return a; } return b; }
fn nodePosition(i: i32) -> vec3f {
  let n = u.emit.z; let f = f32(i); let phase = seedPhase();
  let angle = f*TAU/n+phase*0.15;
  if (u.shape.x < 0.5) {
    return vec3f(0.72+0.22*sin(f*2.4+phase), -1.8+f*0.46, -0.14+0.34*cos(f*1.7));
  }
  if (u.shape.x < 1.5) {
    let r = 1.35*u.shape.z;
    return vec3f(cos(angle)*r, sin(angle)*r, 0.45*sin(angle*2.0+phase));
  }
  if (u.shape.x < 2.5) {
    return vec3f(cos(angle)*1.06, 0.5*sin(angle), -0.52+0.38*sin(angle));
  }
  return vec3f(0.25*sin(f*1.9), (f-(n-1.0)*0.5)*0.83*u.shape.z, 0.25*cos(f*1.7));
}
fn nodeRadius() -> f32 { return select(0.043,0.075,u.shape.x>0.5); }
fn core() -> vec3f {
  if (u.shape.x < 0.5) { return vec3f(-0.06, 1.48, 0.1); }
  if (u.shape.x < 1.5) { return nodePosition(0); }
  if (u.shape.x < 2.5) { return vec3f(0.06, 0.14, 0.16); }
  return nodePosition(i32(u.emit.z)-1);
}
fn ribbons(p: vec3f) -> f32 {
  let phase = seedPhase(); var d = 10.0;
  for (var i = 0; i < 3; i++) {
    let f = f32(i);
    let center = vec2f(0.16*sin(p.y*1.6+phase*0.25), 0.16*cos(p.y*1.3+f));
    let crossSection = rot(p.xz-center, p.y*u.shape.y+f*2.1+0.09*sin(u.motion.y));
    let r = (0.48+0.13*sin(p.y*1.9+phase+f*0.7))*u.shape.z;
    let ring = abs(length(crossSection*vec2f(1.0,1.55))-r)*0.64-u.shape.w;
    let openSide = max(ring, -crossSection.x-0.06);
    let end = abs(p.y+f*0.21)-1.78+f*0.29;
    d = min(d, max(openSide,end));
  }
  return d;
}
fn geometry(p: vec3f) -> Sample {
  var body = 10.0;
  let phase = seedPhase();
  if (u.shape.x < 0.5) {
    body = ribbons(p);
    // A displaced subtraction leaves an open, protective crescent.
    let q = p-vec3f(-0.05,1.39,-0.12);
    let shell = max(length(q)-0.56*u.shape.z, -(length(q-vec3f(0.16,0.16,0.22))-0.55*u.shape.z));
    body = min(body, shell);
  } else if (u.shape.x < 1.5) {
    for (var i = 0; i < 9; i++) {
      if (f32(i) >= u.emit.z) { break; }
      var q = p-nodePosition(i); let r = rot(q.xy, f32(i)*TAU/u.emit.z);
      q = vec3f(r, q.z);
      let shell = max(ellipsoid(q,vec3f(0.35,0.55,0.32)), -ellipsoid(q-vec3f(0.1,0.09,0.12),vec3f(0.34,0.5,0.30)));
      body = min(body, shell);
    }
  } else if (u.shape.x < 2.5) {
    var q = p; q = vec3f(rot(q.xy, 0.18*q.z*u.shape.y), q.z);
    let outer = ellipsoid(q,vec3f(1.04,1.47,0.79)*u.shape.z);
    let inner = ellipsoid(q-vec3f(0.25,0.24,0.29), vec3f(1.02,1.3,0.75)*u.shape.z);
    let opening = max(outer,-inner);
    let ringq = vec3f(q.x, q.z, q.y);
    let torus = length(vec2f(length(ringq.xy)-0.79*u.shape.z, ringq.z*0.72))-u.shape.w;
    body = min(opening, torus);
  } else {
    for (var i = 0; i < 9; i++) {
      if (f32(i) >= u.emit.z) { break; }
      var q = p-nodePosition(i); q = vec3f(rot(q.xy,u.shape.y*f32(i)), q.z);
      let shell = max(ellipsoid(q, vec3f(0.53,0.42,0.35)), -ellipsoid(q-vec3f(0.14,0.09,0.14),vec3f(0.48,0.37,0.32)));
      body = min(body,shell);
    }
  }
  var result = Sample(body,1.0);
  result = nearer(result, Sample(length(p-core())-u.light.y,2.0));
  for (var i = 0; i < 9; i++) {
    if (f32(i) >= u.emit.z) { break; }
    let pos = nodePosition(i);
    let radius = nodeRadius();
    result = nearer(result,Sample(length(p-pos)-radius,3.0));
  }
  return result;
}
fn normalAt(p: vec3f) -> vec3f {
  let e = 0.0015;
  let a = vec3f(1,-1,-1); let b = vec3f(-1,-1,1); let c = vec3f(-1,1,-1); let d = vec3f(1,1,1);
  var n = normalize(a*geometry(p+a*e).d+b*geometry(p+b*e).d+c*geometry(p+c*e).d+d*geometry(p+d*e).d);
  if (u.material.w > 0.001) {
    let q = p*u.material.z+seedPhase(); let e2 = 0.015;
    let base = simplex3(q);
    let grad = vec3f(simplex3(q+vec3f(e2,0,0))-base,simplex3(q+vec3f(0,e2,0))-base,simplex3(q+vec3f(0,0,e2))-base)/e2;
    n = normalize(n-u.material.w*(grad-n*dot(grad,n)));
  }
  return n;
}
// GGX distribution and correlated Smith visibility. Energy-sharing Lambert diffuse.
fn brdf(n: vec3f, v: vec3f, l: vec3f) -> vec3f {
  let nv = max(dot(n,v),0.001); let nl = max(dot(n,l),0.0);
  if (nl <= 0.0) { return vec3f(0.0); }
  let h = normalize(l+v); let nh = max(dot(n,h),0.0); let vh = max(dot(v,h),0.0);
  let a = max(u.material.x*u.material.x,0.002); let a2 = a*a;
  let den = nh*nh*(a2-1.0)+1.0;
  let D = a2/(PI*den*den);
  let ggxV = nl*sqrt(nv*nv*(1.0-a2)+a2);
  let ggxL = nv*sqrt(nl*nl*(1.0-a2)+a2);
  let visibility = 0.5/max(ggxV+ggxL,0.0001);
  let f0 = mix(vec3f(0.04),u.metal.rgb,u.material.y);
  let F = f0+(1.0-f0)*pow(1.0-vh,5.0);
  let specular = D*visibility*F;
  let diffuse = (1.0-F)*(1.0-u.material.y)*u.metal.rgb/PI;
  return (diffuse+specular)*nl;
}
fn shadow(p: vec3f, direction: vec3f, distance: f32) -> f32 {
  var travel = 0.014;
  for (var i = 0; i < 24; i++) {
    if (f32(i)>=u.quality.z || travel >= distance-0.025) { break; }
    let h = geometry(p+direction*travel).d;
    if (h < 0.0007) { return 0.0; }
    travel += max(h*0.78,0.012);
  }
  return 1.0;
}
fn pointLighting(p: vec3f, n: vec3f, v: vec3f, location: vec3f, intensity: vec3f, emitterRadius: f32) -> vec3f {
  let delta = location-p; let d2 = max(dot(delta,delta),0.0001); let dist = sqrt(d2); let l = delta/dist;
  var vis = 1.0;
  if (dot(n,l)>0.0) { vis = shadow(p+n*0.004,l,max(0.0,dist-emitterRadius)); }
  return brdf(n,v,l)*intensity/d2*vis;
}
fn lighting(p: vec3f, n: vec3f, v: vec3f) -> vec3f {
  let key = vec3f(3.8*sin(u.light.z), 2.8, 3.8*cos(u.light.z));
  // Four deterministic area-light samples. Divide total power by sample count.
  // Samples approximate the integral over a finite luminous area, not a fake rim.
  var col = vec3f(0.0);
  for (var i = 0; i < 4; i++) {
    let a = f32(i)*1.5707963+0.785398;
    let pos = key+vec3f(cos(a)*0.9,sin(a)*0.9,0.0);
    col += pointLighting(p,n,v,pos,u.energy.rgb*u.light.x*0.72/(4.0*PI),0.0);
  }
  col += pointLighting(p,n,v,vec3f(-3,-1,2),u.metal.rgb*u.light.x*u.light.w/PI,0.0);
  // Emissive core: isotropic source outside its finite radius, inverse-square.
  let c = core(); let delta = c-p; let d = length(delta);
  if (d > u.light.y+0.003) {
    col += pointLighting(p,n,v,c,u.energy.rgb*u.light.x*0.2/(4.0*PI),u.light.y);
  }
  // Each local node owns a bounded share of the total emitted power.
  for (var i = 0; i < 9; i++) {
    if (f32(i)>=u.emit.z) { break; }
    col += pointLighting(p,n,v,nodePosition(i),u.energy.rgb*u.light.x*0.12/(4.0*PI*u.emit.z),nodeRadius());
  }
  return col;
}
// Henyey-Greenstein with cos(theta) between photon propagation directions.
fn hg(cosTheta: f32) -> f32 {
  let g = u.medium.y;
  return (1.0-g*g)/(4.0*PI*pow(max(1.0+g*g-2.0*g*cosTheta,0.001),1.5));
}
fn densityAt(p: vec3f) -> f32 {
  if (u.medium.x < 0.001) { return 0.0; }
  var axisDistance = 10.0;
  if (u.shape.x < 0.5) {
    let path = vec2f(0.2*sin(p.y*1.25+0.15*sin(u.motion.y)),0.04);
    axisDistance = length(p.xz-path);
  } else if (u.shape.x < 1.5) {
    axisDistance = length(vec2f(length(p.xy)-1.35*u.shape.z,p.z));
  } else if (u.shape.x < 2.5) {
    axisDistance = length(p*vec3f(1.5,0.72,1.5));
  } else { axisDistance = length(p.xz-vec2f(0.12*sin(p.y*2.0),0.0)); }
  let ribbon = exp(-axisDistance*axisDistance*11.0);
  let envelope = exp(-pow(abs(p.y)/2.6,6.0));
  let phase = vec3f(sin(u.motion.y), cos(u.motion.y),0.0)*0.24;
  let detail = 0.65+0.35*simplex3(p*2.3*u.medium.z+phase+seedPhase());
  return u.medium.x*ribbon*envelope*detail;
}
fn volume(ro: vec3f, rd: vec3f, start: f32, end: f32) -> vec4f {
  if (u.medium.x < 0.001 || end <= start) { return vec4f(0,0,0,1); }
  let steps = u.quality.y; let dt = (end-start)/steps;
  var transmission = 1.0; var radiance = vec3f(0.0);
  for (var i = 0; i < 48; i++) {
    if (f32(i)>=steps) { break; }
    let p = ro+rd*(start+(f32(i)+0.5)*dt);
    let sigmaT = densityAt(p)*1.8;
    let stepT = exp(-sigmaT*dt); // Beer-Lambert transmittance.
    let delta = core()-p; let d2 = max(dot(delta,delta),u.light.y*u.light.y);
    let inScatter = u.energy.rgb*u.light.x*0.2/(4.0*PI*d2)*hg(dot(-normalize(delta),-rd));
    // Albedo 0.85; exact segment integral for piecewise-constant coefficients.
    radiance += transmission*(1.0-stepT)*0.85*inScatter;
    transmission *= stepT;
    if (transmission < 0.005) { break; }
  }
  return vec4f(radiance,transmission);
}
@fragment fn fs_main(@builtin(position) pixel: vec4f) -> @location(0) vec4f {
  let global = pixel.xy+u.tile.xy;
  var xy = (global-u.view.xy*0.5)/u.view.y;
  xy.y = -xy.y;
  xy -= vec2f(u.motion.w,u.camera.x)*0.25;
  xy = rot(xy,u.motion.x);
  var ro = vec3f(0,0,6.8); var rd = normalize(vec3f(xy*5.15/u.motion.z,-6.8));
  ro = vec3f(rot(ro.xz,u.camera.y).x,ro.y,rot(ro.xz,u.camera.y).y);
  rd = vec3f(rot(rd.xz,u.camera.y).x,rd.y,rot(rd.xz,u.camera.y).y);
  ro = vec3f(ro.x,rot(ro.yz,u.camera.z)); rd = vec3f(rd.x,rot(rd.yz,u.camera.z));
  let bound = select(3.5,max(3.5,(u.emit.z-1.0)*0.415*u.shape.z+0.8),u.shape.x>2.5);
  let b = dot(ro,rd); let discr = b*b-dot(ro,ro)+bound*bound;
  if (discr <= 0.0) { return vec4f(u.background.rgb,1.0); }
  let near = max(0.0,-b-sqrt(discr)); let far = -b+sqrt(discr);
  var travel = near; var hit = false; var result = Sample(0,0);
  for (var i = 0; i < 160; i++) {
    if (f32(i)>=u.quality.x || travel>=far) { break; }
    result = geometry(ro+rd*travel);
    if (result.d < max(0.0008, travel/u.view.y*0.16)) { hit=true; break; }
    travel += max(result.d*0.63,0.0006);
  }
  var col = u.background.rgb;
  if (hit) {
    let p = ro+rd*travel;
    if (result.material > 1.5) {
      let r = select(u.light.y,nodeRadius(),result.material>2.5);
      let share = select(0.2,0.12/u.emit.z,result.material>2.5);
      col = u.energy.rgb*u.light.x*share/(4.0*PI*PI*r*r);
    } else { col = lighting(p,normalAt(p),-rd); }
  }
  let vol = volume(ro,rd,near,select(far,travel,hit));
  // Keep the finite-half-float render target below overflow at extreme light values.
  return vec4f(clamp(col*vol.a+vol.rgb,vec3f(0.0),vec3f(60000.0)),1.0);
}
