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
  return u.energy.rgb*u.light.x*u.material.z*share/(4.0*PI*PI*radius*radius);
}
fn reflectionRoughness(p: vec3f) -> f32 {
  // Detail modulates the reflection lobe, never the Snell boundary normal.
  return clamp(u.material.x+u.material.w*0.5*simplex3(p*18.0+seedPhase()),0.02,1.0);
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
  let pathBudget = select(select(8u,12u,u.quality.x>80.0),18u,u.quality.x>144.0);
  let depthLimit = select(select(4u,6u,u.quality.x>80.0),8u,u.quality.x>144.0);
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

fn surfaceRadiance(p: vec3f, direction: vec3f) -> vec3f {
  let amount = u.nodes.x*(1.0-u.material.y);
  let glass = glassRadiance(boundaryPoint(p),direction);
  if (amount >= 1.0) { return glass; }
  return mix(lighting(p,normalAt(p),-direction),glass,amount);
}
