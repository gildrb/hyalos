# Rendering contract

## Coordinate systems and state

The camera sees a signed-distance scene, with one scalar unit treated consistently as a model-space distance. The graphic is not calibrated to physical metres or photometric lumens: the power slider is a relative radiometric scale. Local node count, camera, shell shape, phase and all post-processing are parameters, not hidden renderer state.

The seed is an exact 24-bit integer. Integer PCG hashing determines its phase and sensor-grain pattern. `time / duration` determines a periodic phase explicitly. A `16 × vec4f` uniform struct avoids host-shareable padding ambiguity. `uniforms.js` is the single packing definition. Export takes a cloned snapshot before any asynchronous work.

Primary rays use top-origin full-frame pixel positions. Aspect, framing and noise coordinates are based on the complete image, even when the GPU renders an overlapped tile. Ray march budgets are 64/104/160 for draft/balanced/final; medium budgets are 12/24/48 and visibility budgets 10/16/24. They are approximation budgets, not accuracy proofs. Conservative distance steps reduce overstepping; deformed SDFs are approximate distance bounds rather than mathematically certified SDFs.

## Materials

The microfacet BRDF uses roughness-squared GGX and correlated Smith visibility. Schlick Fresnel interpolates between dielectric F0 = 0.04 and the authored metal reflectance, controlled by metallic weight. Lambert diffuse is weighted by `(1-F) * (1-metallic)`. The shader multiplies the BRDF by incident intensity, the surface cosine and inverse-square distance attenuation.

The key light is a four-point quadrature approximation to a finite luminous region. Its sample weights sum to the configured key-light budget. A fill source and finite local emitters also contribute. Visibility is queried using the same scene geometry and stops at emitter boundaries, not the light centre. A finite visibility step budget can miss a distant blocker. Emitter falloff is approximated by an isotropic point source outside a visible finite sphere; very near that sphere, this is not the exact solid-angle integral.

There is no environment-map reflection, indirect surface bounce, subsurface scattering, spectral dispersion or reflection ray recursion. Metal brightness comes from directly evaluated illumination, not a painted rim-light term. Fresnel/GGX is physically based, but the finite sampling and omitted multiple scattering do not make the entire renderer a physically exact light-transport simulation.

## Medium

Procedural Ashima simplex noise modulates a smooth density envelope near the carriers. This is an authored medium, not computational fluid dynamics. Transmission for a segment is `exp(-sigmaT * distance)`. The medium's single-scattering albedo is 0.85 and its phase function is Henyey-Greenstein.

The camera-ray integral uses piecewise-constant midpoint samples. Incoming core radiance uses inverse-square falloff. It does not perform a second shadow or extinction march from each medium sample to the emitter. Consequently, scattered light can leak through occluders and it does not include multiple scattering. This deliberate real-time approximation is separate from surface shadow queries.

## Color and camera

Palette input is OKLCH. Out-of-gamut input is mapped by chroma reduction at fixed perceptual lightness/hue. The display gamut is sRGB, not Display P3 or HDR10. Converted **linear** values are the shader's reflectance and light-color inputs. Intermediate radiance is held in an `rgba16float` target; values can exceed 1. The extreme upper tail is clipped at 60,000 to avoid half-float overflow; this is a storage safety limit, not a physical bound. The displayed/exported image is 8-bit sRGB, not a floating-point EXR.

The finite optical kernel redistributes radiance with normalized weights. It is an art-directable approximation of camera scattering, not a measured lens point-spread function. Luminance-based Reinhard tone mapping, contrast and vignette precede the sRGB transfer function. Grain, dot matrix, Bayer dithering and phosphor are explicit graphic/camera finishes, not new physical illumination. The dots sample the same physical scene instead of replacing it with a random dot field.

## Resource and export behavior

A real vGPU context owns the device, surfaces, HDR target, readback target and two compiled effects. Targets are reused, and binding the HDR Target itself follows texture replacement on resize. Pipelines are prewarmed for HDR, canvas and export formats. Rendering does not read pixels back to the CPU during preview. Paused scenes redraw only after edits/resizes; hidden tabs stop scheduling frames. Export temporarily suspends preview work on the shared context.

Raster exports are limited to 33,554,432 pixels. Default tiles are 1024² plus overlap. The halo is `(3 * bloomRadius + dotSpacing) * fullHeight / 1080`, rounded upward with a 4-pixel margin. It covers the full optical kernel plus cell-centre displacement. Export tiles retain their global coordinates. GPU allocation is bounded per tile, but the CPU still assembles a full RGBA image: an 8K frame alone needs approximately 127 MiB, plus encoding and temporary buffers. Low-memory devices should use smaller outputs.

No adaptive temporal accumulation or stochastic wall-clock samples are used, so a settled frame does not change simply because it was left open. Different quality budgets, output sizes or GPUs can still differ. The recipe records the engine ID and source SHA-256; a changed shader is an explicitly different rendering implementation.

## Primary references

The implementation follows the standard models, not copied proprietary shader code:

- WGSL and WebGPU specifications: https://www.w3.org/TR/WGSL/ and https://www.w3.org/TR/webgpu/
- PBRT, Trowbridge-Reitz microfacets: https://pbr-book.org/4ed/Reflection_Models/Roughness_Using_Microfacet_Theory
- PBRT, phase functions: https://pbr-book.org/4ed/Volume_Scattering/Phase_Functions
- Björn Ottosson, Oklab: https://bottosson.github.io/posts/oklab/
- vGPU's package-versioned documentation: `npx vgpu docs find effect`, `npx vgpu docs find target`, `npx vgpu docs find performance`.
