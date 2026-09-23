fn surfaceRadiance(p: vec3f, direction: vec3f) -> vec3f {
  let surface = boundaryPoint(p);
  return lighting(surface,normalAt(surface),-direction);
}
