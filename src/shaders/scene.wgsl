// Original scene and light transport: MIT, 2026 Hyalos contributors.
// EXCEPTION: marked ORB-31 geometry derives from XorDev's non-commercial source.
// Artist-authored SDF geometry, not a fluid or rigid-body simulation.
@group(0) @binding(1) var<storage, read_write> sampleSums: array<vec4f>;
// Keep the signed surface field separate from its conservative march bound:
// shrinking a field for domain warp must never turn an empty hole into a hit.
struct Sample { d: f32, material: f32, step: f32 };
fn nearer(a: Sample, b: Sample) -> Sample {
  if (a.d < b.d) { return Sample(a.d,a.material,min(a.step,b.step)); }
  return Sample(b.d,b.material,min(a.step,b.step));
}
// The sculpture transform is periodic and invertible; it never uses wall-clock state.
fn sculptureSpace(p: vec3f) -> vec3f {
  let xy = rot(p.xy, seedPhase()*0.12+0.12*sin(u.motion.y));
  let q = vec3f(xy,p.z);
  let xz = rot(q.xz,q.y*u.shape.y*0.18);
  return vec3f(xz.x,q.y,xz.y);
}
fn sculptureWorld(p: vec3f) -> vec3f {
  let xz = rot(p.xz,-p.y*u.shape.y*0.18);
  let q = vec3f(xz.x,p.y,xz.y);
  return vec3f(rot(q.xy,-seedPhase()*0.12-0.12*sin(u.motion.y)),q.z);
}
// ORB-31 integration and warped-volume subtraction below derive from XorDev's
// non-commercial ORB-31 shader, not the MIT transport code. See third-party notices.
// Preserve the installed shape's units: radius 2.6, warp .9, frequency 5.25, k .42.
// Only a uniform scale and true, invertible rotations surround the supplied SDF.
fn holeScale() -> f32 { return 0.55*u.shape.z; }
fn holeSpace(p: vec3f) -> vec3f {
  let q = vec3f(rot(p.xy,seedPhase()+0.14*sin(u.motion.y)),p.z);
  let xz = rot(q.xz,seedPhase()*0.18+0.25*sin(u.motion.y));
  return vec3f(xz.x,q.y,xz.y);
}
fn holeWorld(p: vec3f) -> vec3f {
  let xz = rot(p.xz,-seedPhase()*0.18-0.25*sin(u.motion.y));
  let q = vec3f(xz.x,p.y,xz.y);
  return vec3f(rot(q.xy,-seedPhase()-0.14*sin(u.motion.y)),q.z);
}
fn coronaDistance(p: vec3f) -> f32 {
  let scale = holeScale();
  let q = holeSpace(p)/scale;
  return orb31CoronaSDF(q,2.6,u.emit.x,u.emit.w,u.finish.w)*scale;
}
fn bodyStepScale() -> f32 {
  // ||Jwarp|| <= 1+frequency/warp. The upstream smooth maximum has convex
  // gradient weights and cannot increase that Lipschitz bound.
  let slope = u.emit.w/max(u.emit.x,0.001);
  if (u.shape.x > 8.5) { return 1.0/(1.0+slope); }
  // Original body fields are already approximate bounds, not certified SDFs.
  // Add margin for their composition as well as the signed amount interpolation.
  return 1.0/(1.0+u.view.z*(slope+0.5));
}
fn bodyMarchDistance(p: vec3f, field: f32) -> f32 {
  let distance = field*bodyStepScale();
  if (u.shape.x > 8.5) {
    // Subtraction never grows the original sphere. Its exterior distance is a
    // tighter safe bound far away, avoiding wasted steps in the existing budgets.
    return max(distance,length(p)-2.6*holeScale());
  }
  return distance;
}
fn dropCenter(i: i32) -> vec3f {
  let f = f32(i); let phase = seedPhase();
  return vec3f(0.28*sin(f*2.1+phase), (f-(u.emit.z-1.0)*0.5)*(0.36+0.16*u.shape.z), 0.24*cos(f*1.7+phase));
}
fn knotPoint(t: f32) -> vec3f {
  let coil = 3.0*t+seedPhase()*0.2+0.12*sin(u.motion.y);
  let r = 0.85*u.shape.z+(0.3+u.emit.z*0.012)*cos(coil);
  return vec3f(r*cos(2.0*t),r*sin(2.0*t)/0.82,0.44*sin(coil));
}
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
  if (u.shape.x < 3.5) {
    return vec3f(0.25*sin(f*1.9), (f-(n-1.0)*0.5)*0.83*u.shape.z, 0.25*cos(f*1.7));
  }
  if (u.shape.x < 4.5) { return sculptureWorld(knotPoint(angle)); }
  if (u.shape.x < 5.5) {
    return sculptureWorld(vec3f(0.56*cos(angle),0.95*sin(angle),0.2*sin(angle*2.0+phase))*u.shape.z);
  }
  if (u.shape.x < 6.5) { return sculptureWorld(dropCenter(i)); }
  if (u.shape.x < 7.5) {
    let y = -1.55+f*1.95/max(n-1.0,1.0);
    return sculptureWorld(vec3f(0.07*sin(y*1.7),y,-0.19));
  }
  if (u.shape.x < 8.5) {
    return sculptureWorld(vec3f(0.53*u.shape.z*cos(angle),0.35+0.72*sin(angle),-0.48));
  }
  // Corona's small practicals sit behind the shell, not in the open central void.
  let r = 2.6*holeScale();
  return vec3f(0.8*r*cos(angle),0.8*r*sin(angle),-0.7*r);
}
fn nodeRadius() -> f32 {
  if (u.shape.x > 8.5) { return 0.035; }
  return select(0.043,0.075,u.shape.x>0.5);
}
fn core() -> vec3f {
  if (u.shape.x < 0.5) { return vec3f(-0.06, 1.48, 0.1); }
  if (u.shape.x < 1.5) { return nodePosition(0); }
  if (u.shape.x < 2.5) { return vec3f(0.06, 0.14, 0.16); }
  if (u.shape.x < 3.5) { return nodePosition(i32(u.emit.z)-1); }
  if (u.shape.x < 4.5) { return sculptureWorld(knotPoint(0.0)+vec3f(0.0,0.0,0.12)); }
  if (u.shape.x < 5.5) { return sculptureWorld(vec3f(0.0,0.28,-0.18)*u.shape.z); }
  if (u.shape.x < 6.5) { return nodePosition(i32(u.emit.z)/2); }
  if (u.shape.x < 7.5) { return sculptureWorld(vec3f(-0.2*u.shape.z,1.24,-0.22)); }
  if (u.shape.x < 8.5) { return sculptureWorld(vec3f(0.12,0.74,-0.54)); }
  return vec3f(-0.68,0.45,-0.75)*(2.6*holeScale());
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
fn reliquary(p: vec3f) -> f32 {
  let local = sculptureSpace(p);
  // A tapered, fluted stem: its small lateral sweep is not a noise displacement.
  let y = clamp(local.y,-1.92,0.65);
  let center = 0.07*sin(y*1.7);
  let q = vec3f(local.x-center,local.y,local.z);
  let taper = (y+1.92)/2.57;
  let flute = cos(atan2(q.z,q.x+0.0000001)*(u.emit.z+3.0)+y*u.shape.y);
  let radius = (0.075+0.12*taper+0.026*flute+u.shape.w*0.45)*u.shape.z;
  var d = max(length(q.xz)-radius,max(-1.92-local.y,local.y-0.65));
  // Three finite collars break the shaft into ceremonial segments.
  for (var i = 0; i < 3; i++) {
    let h = -1.35+f32(i)*0.78;
    let r = (0.15+f32(i)*0.04+u.shape.w*0.4)*u.shape.z;
    let collar = length(vec2f(length(q.xz)-r,(q.y-h)*0.72))-(0.035+u.shape.w*0.22);
    d = min(d,collar);
  }
  // Offset circular subtraction makes a genuinely open crescent, not a ball.
  let crest = vec3f(local.x/u.shape.z,(local.y-1.25)/1.1,local.z);
  let outer = length(crest.xy)-0.74;
  let inner = length(crest.xy-vec2f(-0.25,0.13))-0.7;
  let crescent = max(max(outer,-inner),abs(crest.z)-(0.06+u.shape.w*0.65));
  d = min(d,crescent*min(u.shape.z,1.0));
  return d*0.65/(1.0+abs(u.shape.y)*0.35);
}
fn sanctum(p: vec3f) -> f32 {
  let q = sculptureSpace(p);
  var d = 10.0;
  // Five staggered vault ribs share a deep open portal. The feet flare like folds;
  // depth and unequal hem lengths distinguish a draped volume from flat rings.
  for (var i = 0; i < 5; i++) {
    let f = f32(i);
    let spring = 0.3+0.035*f;
    let lower = clamp(spring-q.y,0.0,2.2);
    let sweep = 0.035*sin(q.y*1.8+f*0.7+seedPhase()*0.2);
    let x = (q.x-sweep-sign(q.x)*lower*0.1)/u.shape.z;
    let arch = length(vec2f(x,max(q.y-spring,0.0)*0.85));
    let radius = 0.59+f*0.16;
    let rib = abs(arch-radius)-(0.035+u.shape.w*0.72);
    let depth = abs(q.z-(-0.48+f*0.23+lower*0.04))-(0.085+u.shape.w*0.35);
    let hem = -1.9+f*0.105+0.055*sin(f*1.7)-q.y;
    d = min(d,max(max(rib*min(u.shape.z,1.0),depth),hem));
  }
  return d*0.72/(1.0+abs(u.shape.y)*0.35);
}
fn originalBodyDistance(p: vec3f) -> f32 {
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
  } else if (u.shape.x < 3.5) {
    for (var i = 0; i < 9; i++) {
      if (f32(i) >= u.emit.z) { break; }
      var q = p-nodePosition(i); q = vec3f(rot(q.xy,u.shape.y*f32(i)), q.z);
      let shell = max(ellipsoid(q, vec3f(0.53,0.42,0.35)), -ellipsoid(q-vec3f(0.14,0.09,0.14),vec3f(0.48,0.37,0.32)));
      body = min(body,shell);
    }
  } else if (u.shape.x < 4.5) {
    let local = sculptureSpace(p);
    let q = vec3f(local.x,local.y*0.82,local.z);
    let angle = atan2(q.y,q.x);
    let radial = length(q.xy);
    // Two radial branches of an original (2,3) woven torus knot.
    // This implicit tube has a conservative step scale, not an exact curve SDF.
    for (var i = 0; i < 2; i++) {
      let t = angle*0.5+f32(i)*PI;
      let coil = 3.0*t+phase*0.2+0.12*sin(u.motion.y);
      let center = vec2f(0.85*u.shape.z+(0.3+u.emit.z*0.012)*cos(coil),0.44*sin(coil));
      let radius = (0.075+u.shape.w*1.45)*(1.0+0.08*sin(t*2.0*u.emit.z+phase));
      body = min(body,length(vec2f(radial,q.z)-center)-radius);
    }
    body *= 0.42/(1.0+abs(u.shape.y)*0.35);
  } else if (u.shape.x < 5.5) {
    let q = sculptureSpace(p);
    let frequency = 1.8+u.emit.z*0.12;
    let wave = q*frequency+vec3f(phase*0.23,0.17*sin(u.motion.y),0.21*cos(u.motion.y));
    let g = dot(sin(wave),cos(wave.yzx));
    // Finite-thickness gyroid level set, capped by a closed ellipsoidal volume.
    let sheet = (abs(g)-u.shape.w*frequency*2.0)/(3.5*frequency);
    let boundary = ellipsoid(q,vec3f(0.95,1.65,0.78)*u.shape.z)*0.72;
    body = max(sheet,boundary)/(1.0+abs(u.shape.y)*0.5);
  } else if (u.shape.x < 6.5) {
    let q = sculptureSpace(p);
    for (var i = 0; i < 9; i++) {
      if (f32(i) >= u.emit.z) { break; }
      let radius = (0.18+u.shape.w*1.4)*(0.85+0.3*rand(u32(i)+u32(u.view.w)));
      let offset = q-dropCenter(i);
      let tilted = vec3f(rot(offset.xy,u.shape.y*0.24*sin(f32(i)+phase)),offset.z);
      body = min(body,ellipsoid(tilted,vec3f(0.9,1.45,0.8)*radius));
    }
    body *= 0.62/(1.0+abs(u.shape.y)*0.5);
  } else if (u.shape.x < 7.5) {
    body = reliquary(p);
  } else if (u.shape.x < 8.5) {
    body = sanctum(p);
  } else {
    body = coronaDistance(p);
  }
  return body;
}
// ORB-31/XorDev non-commercial derived geometry: the same warped-volume
// subtraction applied to each original sculpture, not a noise mask or shading trick.
fn bodyDistance(p: vec3f) -> f32 {
  let base = originalBodyDistance(p);
  let amount = u.view.z;
  if (u.shape.x > 8.5 || amount <= 0.0) { return base; }
  let scale = holeScale();
  let q = holeSpace(p)/scale;
  let w = sin(q.xzy*u.emit.w)/max(u.emit.x,0.001);
  let warped = vec3f(q.x+w.z,q.y+w.y,q.z+w.x);
  let cutter = originalBodyDistance(holeWorld(warped*scale));
  let carved = -orb31Smin(cutter,-base,u.finish.w*scale);
  // Signed interpolation shrinks the solid continuously; a positive zero-set
  // crossing really removes material. Exactly zero bypasses all hole processing.
  return mix(base,carved,amount);
}
fn emitterGeometry(p: vec3f) -> Sample {
  var result = Sample(100.0,0.0,100.0);
  let coreDistance = length(p-core())-u.light.y;
  result = nearer(result, Sample(coreDistance,2.0,coreDistance));
  for (var i = 0; i < 9; i++) {
    if (f32(i) >= u.emit.z) { break; }
    let pos = nodePosition(i);
    let radius = nodeRadius();
    let distance = length(p-pos)-radius;
    result = nearer(result,Sample(distance,3.0,distance));
  }
  return result;
}
fn geometry(p: vec3f) -> Sample {
  let body = bodyDistance(p);
  return nearer(Sample(body,1.0,bodyMarchDistance(p,body)),emitterGeometry(p));
}
fn sceneBound() -> f32 {
  if (u.shape.x > 8.5) {
    // The smooth subtraction never grows the radius-2.6 sphere. Include every
    // rear practical and the largest configurable core radius as well.
    return max(3.5,1.2*2.6*holeScale()+u.light.y);
  }
  if (u.shape.x > 2.5 && u.shape.x < 3.5) {
    return max(3.5,(u.emit.z-1.0)*0.415*u.shape.z+0.8);
  }
  if (u.shape.x > 7.5) {
    // Covers the flared outer rib at every spread/thickness setting; rotations
    // and the sculpture twist preserve distance from the origin.
    return max(3.5,length(vec3f(1.45*u.shape.z+0.28,2.1,0.9)));
  }
  return 3.5;
}
fn bodyGradient(p: vec3f) -> vec3f {
  let e = 0.0006;
  let a = vec3f(1,-1,-1); let b = vec3f(-1,-1,1); let c = vec3f(-1,1,-1); let d = vec3f(1,1,1);
  return (a*bodyDistance(p+a*e)+b*bodyDistance(p+b*e)+c*bodyDistance(p+c*e)+d*bodyDistance(p+d*e))/(4.0*e);
}
fn bodyNormal(p: vec3f) -> vec3f {
  let gradient = bodyGradient(p);
  return gradient/max(length(gradient),0.000001);
}
fn boundaryPoint(p: vec3f) -> vec3f {
  // Primary-ray tolerance grows with pixel footprint. Project back onto the body
  // before launching an optical ray, so thin sheets do not start in the wrong medium.
  var q = p;
  for (var i = 0; i < 3; i++) {
    let gradient = bodyGradient(q);
    q -= gradient*bodyDistance(q)/max(dot(gradient,gradient),0.000001);
  }
  return q;
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
    let sample = geometry(p+direction*travel);
    if (sample.d < 0.0007) { return 0.0; }
    travel += max(sample.step*0.78,0.012*bodyStepScale());
  }
  return 1.0;
}
fn keyPosition() -> vec3f {
  return vec3f(3.8*sin(u.light.z),2.8,3.8*cos(u.light.z));
}
fn keyCone() -> vec3f {
  // camera.w is the outer half-angle in radians; the inner 80% is fully lit.
  let outer = cos(u.camera.w); let inner = cos(u.camera.w*0.8);
  // Integral of the cosine-space smoothstep over the sphere is
  // 2*PI*(1-(outer+inner)/2). Normalize to mean one, preserving key power.
  return vec3f(outer,inner,2.0/max(1.0-0.5*(outer+inner),0.000001));
}
fn keyAngularMask(outgoing: vec3f, axis: vec3f, cone: vec3f) -> f32 {
  let cosine = clamp(dot(outgoing,axis),-1.0,1.0);
  let spot = smoothstep(cone.x,cone.y,cosine)*cone.z;
  // medium.w redistributes power, rather than adding a brighter second emitter.
  return mix(1.0,spot,u.medium.w);
}
fn pointLighting(p: vec3f, n: vec3f, v: vec3f, location: vec3f, intensity: vec3f, emitterRadius: f32) -> vec3f {
  let delta = location-p; let d2 = max(dot(delta,delta),0.0001); let dist = sqrt(d2); let l = delta/dist;
  var vis = 1.0;
  if (dot(n,l)>0.0) { vis = shadow(p+n*0.004,l,max(0.0,dist-emitterRadius)); }
  return brdf(n,v,l)*intensity/d2*vis;
}
fn lighting(p: vec3f, n: vec3f, v: vec3f) -> vec3f {
  let key = keyPosition();
  var axis = vec3f(0.0); var cone = vec3f(0.0);
  if (u.medium.w > 0.0) { axis = -normalize(key); cone = keyCone(); }
  // Four deterministic area-light samples. Divide total power by sample count.
  // Samples approximate the integral over a finite luminous area, not a fake rim.
  var col = vec3f(0.0);
  for (var i = 0; i < 4; i++) {
    let a = f32(i)*1.5707963+0.785398;
    let pos = key+vec3f(cos(a)*0.9,sin(a)*0.9,0.0);
    var intensity = u.energy.rgb*u.light.x*0.72/(4.0*PI);
    if (u.medium.w > 0.0) {
      // Parallel lobes across the finite source share the centre's origin-facing axis.
      let outgoing = p-pos;
      intensity *= keyAngularMask(outgoing/max(length(outgoing),0.0001),axis,cone);
    }
    col += pointLighting(p,n,v,pos,intensity,0.0);
  }
  if (u.light.w > 0.0) {
    col += pointLighting(p,n,v,vec3f(-3,-1,2),u.metal.rgb*u.light.x*u.light.w/PI,0.0);
  }
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
// Bounded dielectric transport. Body boundaries are queried independently of emitters.
// Unresolved paths contribute zero: a step/bounce limit is NOT an environment hit.
struct OpticalHit { p: vec3f, distance: f32, material: f32 };
struct Interface { direction: vec3f, fresnel: f32 };
struct GlassRay {
  origin: vec3f, direction: vec3f, weight: vec3f,
  inside: bool, roughness: f32, depth: u32,
};
const OPTICAL_BIAS: f32 = 0.0015;
fn dielectric(direction: vec3f, normal: vec3f, etaI: f32, etaT: f32) -> Interface {
  if (abs(etaI-etaT) < 0.000001) { return Interface(direction,0.0); }
  let cosineI = clamp(-dot(direction,normal),0.0,1.0);
  let eta = etaI/etaT;
  let sineT2 = eta*eta*max(0.0,1.0-cosineI*cosineI);
  if (sineT2 >= 1.0) { return Interface(vec3f(0.0),1.0); }
  let cosineT = sqrt(1.0-sineT2);
  // Exact unpolarized dielectric Fresnel, including the critical angle.
  let rs = (etaI*cosineI-etaT*cosineT)/max(etaI*cosineI+etaT*cosineT,0.000001);
  let rp = (etaT*cosineI-etaI*cosineT)/max(etaT*cosineI+etaI*cosineT,0.000001);
  let transmitted = normalize(eta*direction+(eta*cosineI-cosineT)*normal);
  return Interface(transmitted,clamp(0.5*(rs*rs+rp*rp),0.0,1.0));
}
fn studioPanel(direction: vec3f, center: vec3f, width: vec2f, roughness: f32) -> f32 {
  let horizontal = normalize(cross(vec3f(0.0,1.0,0.0),center));
  let vertical = cross(center,horizontal);
  // Analytic, approximately integral-preserving Gaussian lobe broadening.
  // This is a deterministic environment convolution, not sampled GGX transport.
  let blur = roughness*roughness*1.35;
  let variance = width*width+vec2f(blur*blur);
  let coordinate = vec2f(dot(direction,horizontal),dot(direction,vertical));
  let attenuation = width.x*width.y/sqrt(variance.x*variance.y);
  return attenuation*exp(-0.5*dot(coordinate*coordinate,1.0/variance))*smoothstep(0.0,0.2,dot(direction,center));
}
fn studioRadiance(direction: vec3f, roughness: f32) -> vec3f {
  let key = normalize(vec3f(3.8*sin(u.light.z),2.8,3.8*cos(u.light.z)));
  let back = normalize(vec3f(-key.x,-0.12,-key.z));
  let fill = normalize(vec3f(-3.0,-1.0,2.0));
  let keyShape = studioPanel(direction,key,vec2f(0.11,0.48),roughness);
  let backShape = studioPanel(direction,back,vec2f(0.16,0.62),roughness);
  var fillShape = 0.0;
  if (u.light.w > 0.0) { fillShape = studioPanel(direction,fill,vec2f(0.48,0.52),roughness); }
  // Distant luminous panels: no inverse-square term at infinity. Palette inputs
  // are already linear, and display transfer still occurs only in the post pass.
  return u.background.rgb+u.light.x*(u.energy.rgb*(0.1*keyShape+0.065*backShape)+u.metal.rgb*u.light.w*0.055*fillShape);
}
fn opticalMarch(origin: vec3f, direction: vec3f, inside: bool) -> OpticalHit {
  let bound = sceneBound();
  let b = dot(origin,direction);
  let discriminant = b*b-dot(origin,origin)+bound*bound;
  if (discriminant <= 0.0) {
    return OpticalHit(origin,0.0,select(0.0,-1.0,inside));
  }
  let end = -b+sqrt(discriminant);
  var travel = 0.0; var previous = 0.0;
  let budget = min(112u,u32(u.quality.x*0.55)+16u);
  for (var step = 0u; step < 112u; step++) {
    if (step >= budget) { break; }
    if (travel > end) {
      return OpticalHit(origin+direction*travel,travel,select(0.0,-1.0,inside));
    }
    let p = origin+direction*travel;
    let body = bodyDistance(p);
    // A sign crossing is refined on the actual body, never on a luminous sphere.
    if ((body < 0.0) != inside) {
      if (step == 0u) { return OpticalHit(p,travel,-1.0); }
      var lo = previous; var hi = travel;
      for (var refine = 0; refine < 7; refine++) {
        let mid = (lo+hi)*0.5;
        if ((bodyDistance(origin+direction*mid) < 0.0) == inside) { lo=mid; } else { hi=mid; }
      }
      let distance = (lo+hi)*0.5;
      return OpticalHit(origin+direction*distance,distance,1.0);
    }
    let emitter = emitterGeometry(p);
    if (emitter.d < 0.00025) { return OpticalHit(p,travel,emitter.material); }
    if (abs(body) < 0.00012) {
      let outgoing = dot(direction,bodyNormal(p));
      if (select((outgoing < -0.0001),(outgoing > 0.0001),inside)) {
        return OpticalHit(boundaryPoint(p),travel,1.0);
      }
    }
    previous = travel;
    travel += max(min(abs(bodyMarchDistance(p,body)),emitter.d)*0.72,0.00035*bodyStepScale());
  }
  return OpticalHit(origin+direction*travel,travel,-1.0);
}
fn emittedRadiance(material: f32) -> vec3f {
  let radius = select(u.light.y,nodeRadius(),material>2.5);
  let share = select(0.2,0.12/u.emit.z,material>2.5);
  return u.energy.rgb*u.light.x*share/(4.0*PI*PI*radius*radius);
}
fn reflectionRoughness(p: vec3f) -> f32 {
  // Detail modulates the reflection lobe, never the Snell boundary normal.
  return clamp(u.material.x+u.material.w*0.5*simplex3(p*u.material.z+seedPhase()),0.02,1.0);
}
fn significant(weight: vec3f) -> bool { return max(weight.x,max(weight.y,weight.z)) > 0.0005; }
fn traceGlass(p: vec3f, normal: vec3f, direction: vec3f, ior: f32, sigmaA: vec3f) -> vec3f {
  let entry = dielectric(direction,normal,1.0,ior);
  var stack: array<GlassRay,8>;
  var pending = 0u;
  // Radiance-mode eta² factors cancel for paths starting and ending in air, but
  // are retained for a path terminating on an emitter embedded in the body.
  var ray = GlassRay(p-normal*OPTICAL_BIAS,entry.direction,vec3f((1.0-entry.fresnel)/(ior*ior)),true,0.0,1u);
  // Evaluate the visible front reflection first; dense transmitted paths must not
  // exhaust the entire finite budget before the primary highlight is considered.
  if (entry.fresnel > 0.0005) {
    stack[0] = ray;
    pending = 1u;
    ray = GlassRay(p+normal*OPTICAL_BIAS,reflect(direction,normal),vec3f(entry.fresnel),false,reflectionRoughness(p),1u);
  }
  var radiance = vec3f(0.0);
  let pathBudget = select(select(8u,12u,u.quality.x>64.0),18u,u.quality.x>104.0);
  let depthLimit = select(select(4u,6u,u.quality.x>64.0),8u,u.quality.x>104.0);
  for (var segment = 0u; segment < 18u; segment++) {
    if (segment >= pathBudget) { break; }
    var finished = !significant(ray.weight) || ray.depth > depthLimit;
    if (!finished) {
      let hit = opticalMarch(ray.origin,ray.direction,ray.inside);
      if (ray.inside) {
        // Path length is in scene units, accumulated for EVERY internal segment.
        ray.weight *= exp(-sigmaA*(hit.distance+OPTICAL_BIAS));
      }
      if (hit.material < 0.0) {
        finished = true;
      } else if (hit.material == 0.0) {
        radiance += ray.weight*studioRadiance(ray.direction,ray.roughness);
        finished = true;
      } else if (hit.material > 1.5) {
        radiance += ray.weight*emittedRadiance(hit.material);
        finished = true;
      } else {
        let outward = bodyNormal(hit.p);
        let n = select(outward,-outward,ray.inside);
        let etaI = select(1.0,ior,ray.inside);
        let etaT = select(ior,1.0,ray.inside);
        let boundary = dielectric(ray.direction,n,etaI,etaT);
        let reflected = reflect(ray.direction,n);
        let roughness = max(ray.roughness,reflectionRoughness(hit.p));
        if (boundary.fresnel >= 1.0) {
          // Total internal reflection retains the path; no fictitious exit ray.
          ray.origin = hit.p+n*OPTICAL_BIAS;
          ray.direction = reflected;
          ray.roughness = roughness;
          ray.depth += 1u;
        } else {
          let reflectedWeight = ray.weight*boundary.fresnel;
          if (pending < 8u && significant(reflectedWeight) && ray.depth < depthLimit) {
            stack[pending] = GlassRay(hit.p+n*OPTICAL_BIAS,reflected,reflectedWeight,ray.inside,roughness,ray.depth+1u);
            pending += 1u;
          }
          ray.weight *= (1.0-boundary.fresnel)*sq(etaI/etaT);
          ray.origin = hit.p-n*OPTICAL_BIAS;
          ray.direction = boundary.direction;
          ray.inside = !ray.inside;
          ray.depth += 1u;
        }
      }
    }
    if (finished) {
      if (pending == 0u) { break; }
      pending -= 1u;
      ray = stack[pending];
    }
  }
  // Any weight left in the bounded stack is deliberately discarded, not filled.
  return radiance;
}
fn glassRadiance(p: vec3f, direction: vec3f) -> vec3f {
  let normal = bodyNormal(p);
  let sigmaA = -log(clamp(u.metal.rgb,vec3f(0.001),vec3f(1.0)))*u.nodes.w;
  if (u.nodes.z == 0.0) {
    return traceGlass(p,normal,direction,u.nodes.y,sigmaA);
  }
  // Cauchy-like RGB quadrature at 610/550/460 nm, not a spectral path tracer.
  // Dispersion specifies the blue-minus-red IOR span; green uses the IOR slider.
  let inverseLambda2 = 1.0/(vec3f(0.61,0.55,0.46)*vec3f(0.61,0.55,0.46));
  let shift = (inverseLambda2-vec3f(1.0/(0.55*0.55)))/(1.0/(0.46*0.46)-1.0/(0.61*0.61));
  let indices = max(vec3f(1.0),vec3f(u.nodes.y)+u.nodes.z*shift);
  let red = traceGlass(p,normal,direction,indices.x,sigmaA).r;
  let green = traceGlass(p,normal,direction,indices.y,sigmaA).g;
  let blue = traceGlass(p,normal,direction,indices.z,sigmaA).b;
  return vec3f(red,green,blue);
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
  } else if (u.shape.x < 3.5) {
    axisDistance = length(p.xz-vec2f(0.12*sin(p.y*2.0),0.0));
  } else if (u.shape.x < 4.5) {
    let q = sculptureSpace(p);
    axisDistance = length(vec2f(length(vec2f(q.x,q.y*0.82))-0.85*u.shape.z,q.z));
  } else if (u.shape.x < 5.5) {
    axisDistance = length(sculptureSpace(p)/vec3f(1.0,1.7,0.85))/u.shape.z;
  } else if (u.shape.x > 8.5) {
    axisDistance = abs(length(p)-2.6*holeScale());
  } else {
    let q = sculptureSpace(p);
    axisDistance = length(q.xz-vec2f(0.1*sin(q.y*2.0+seedPhase()),0.0));
  }
  let ribbon = exp(-axisDistance*axisDistance*11.0);
  let envelope = exp(-pow(abs(p.y)/2.6,6.0));
  let phase = vec3f(sin(u.motion.y), cos(u.motion.y),0.0)*0.24;
  let detail = 0.65+0.35*simplex3(p*2.3*u.medium.z+phase+seedPhase());
  if (u.medium.w > 0.0) {
    // Authored stage haze: a broad radial envelope vanishing at the march bound.
    // Keep the same vertical falloff/noise, and the exact legacy ribbon at zero beam.
    let stage = 1.0-smoothstep(0.45,1.0,length(p)/sceneBound());
    return u.medium.x*mix(ribbon,stage,u.medium.w)*envelope*detail;
  }
  return u.medium.x*ribbon*envelope*detail;
}
fn volume(ro: vec3f, rd: vec3f, start: f32, end: f32) -> vec4f {
  if (u.medium.x < 0.001 || end <= start) { return vec4f(0,0,0,1); }
  let steps = u.quality.y; let dt = (end-start)/steps;
  var transmission = 1.0; var radiance = vec3f(0.0);
  let source = core();
  var key = vec3f(0.0); var axis = vec3f(0.0); var cone = vec3f(0.0);
  if (u.medium.w > 0.0) {
    key = keyPosition(); axis = -normalize(key); cone = keyCone();
  }
  for (var i = 0; i < 48; i++) {
    if (f32(i)>=steps) { break; }
    let p = ro+rd*(start+(f32(i)+0.5)*dt);
    let sigmaT = densityAt(p)*1.8;
    let stepT = exp(-sigmaT*dt); // Beer-Lambert transmittance.
    let delta = source-p; let d2 = max(dot(delta,delta),u.light.y*u.light.y);
    var inScatter = u.energy.rgb*u.light.x*0.2/(4.0*PI*d2)*hg(dot(-normalize(delta),-rd));
    if (u.medium.w > 0.0) {
      // One centre sample replaces the four-point key quadrature in the medium.
      // Its intensity is their sum, .72*power/PI; radius .9 is in scene units.
      let keyDelta = key-p; let keyDistance2 = dot(keyDelta,keyDelta);
      let towardKey = keyDelta/sqrt(max(keyDistance2,0.00000001));
      let mask = keyAngularMask(-towardKey,axis,cone);
      let incoming = u.energy.rgb*u.light.x*0.72/(PI*max(keyDistance2,0.81));
      // HG compares incoming photon propagation (-towardKey) to outgoing (-rd).
      // The authored beam fade restores the legacy omission continuously at zero.
      // No light-side extinction/shadow march: this single-scatter model can leak
      // through blockers, and the finite-radius clamp is not exact area transport.
      inScatter += u.medium.w*incoming*mask*hg(clamp(dot(-towardKey,-rd),-1.0,1.0));
    }
    // Albedo 0.85; exact segment integral for piecewise-constant coefficients.
    radiance += transmission*(1.0-stepT)*0.85*inScatter;
    transmission *= stepT;
    if (transmission < 0.005) { break; }
  }
  return vec4f(radiance,transmission);
}
fn sceneRadiance(global: vec2f) -> vec3f {
  var xy = (global-u.view.xy*0.5)/u.view.y;
  xy.y = -xy.y;
  xy -= vec2f(u.motion.w,u.camera.x)*0.25;
  xy = rot(xy,u.motion.x);
  var ro = vec3f(0,0,6.8); var rd = normalize(vec3f(xy*5.15/u.motion.z,-6.8));
  ro = vec3f(rot(ro.xz,u.camera.y).x,ro.y,rot(ro.xz,u.camera.y).y);
  rd = vec3f(rot(rd.xz,u.camera.y).x,rd.y,rot(rd.xz,u.camera.y).y);
  ro = vec3f(ro.x,rot(ro.yz,u.camera.z)); rd = vec3f(rd.x,rot(rd.yz,u.camera.z));
  let bound = sceneBound();
  let b = dot(ro,rd); let discr = b*b-dot(ro,ro)+bound*bound;
  if (discr <= 0.0) { return u.background.rgb; }
  let near = max(0.0,-b-sqrt(discr)); let far = -b+sqrt(discr);
  var travel = near; var hit = false; var result = Sample(0,0,0);
  for (var i = 0; i < 160; i++) {
    if (f32(i)>=u.quality.x || travel>=far) { break; }
    result = geometry(ro+rd*travel);
    if (result.d < max(0.0008, travel/u.view.y*0.16)) { hit=true; break; }
    travel += max(result.step*0.63,0.0006*bodyStepScale());
  }
  var col = u.background.rgb;
  if (hit) {
    let p = ro+rd*travel;
    if (result.material > 1.5) {
      let r = select(u.light.y,nodeRadius(),result.material>2.5);
      let share = select(0.2,0.12/u.emit.z,result.material>2.5);
      col = u.energy.rgb*u.light.x*share/(4.0*PI*PI*r*r);
    } else {
      let transmission = u.nodes.x*(1.0-u.material.y);
      if (transmission <= 0.0) {
        col = lighting(p,normalAt(p),-rd);
      } else {
        let glass = glassRadiance(boundaryPoint(p),rd);
        col = glass;
        if (transmission < 1.0) {
          col = mix(lighting(p,normalAt(p),-rd),glass,transmission);
        }
      }
    }
  }
  let vol = volume(ro,rd,near,select(far,travel,hit));
  // Keep the finite-half-float render target below overflow at extreme light values.
  return clamp(col*vol.a+vol.rgb,vec3f(0.0),vec3f(60000.0));
}
@fragment fn fs_main(@builtin(position) pixel: vec4f) -> @location(0) vec4f {
  let global = pixel.xy+u.tile.xy;
  let grid = clamp(u32(u.quality.w),1u,3u);
  if (grid == 1u) { return vec4f(sceneRadiance(global),1.0); }
  let sampleIndex = u32(u.emit.y);
  let x = sampleIndex%grid; let y = sampleIndex/grid;
  // Integrate one complete scene ray at its cell center in full-frame coordinates.
  let offset = (vec2f(f32(x),f32(y))+vec2f(0.5))/f32(grid)-vec2f(0.5);
  let pixelIndex = u32(pixel.y)*u32(u.tile.z)+u32(pixel.x);
  var radiance = vec3f(0.0);
  if (sampleIndex > 0u) { radiance = sampleSums[pixelIndex].rgb; }
  radiance += sceneRadiance(global+offset);
  // Preserve the sequential f32 sum between submissions, before target conversion.
  sampleSums[pixelIndex] = vec4f(radiance,1.0);
  return vec4f(radiance/f32(grid*grid),1.0);
}
