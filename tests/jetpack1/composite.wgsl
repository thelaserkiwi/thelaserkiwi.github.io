
struct FixedData
{
  framebufferDimensions : vec2<i32>,
  textureDimensions     : vec2<i32>,
}

@group(0) @binding(0) var<uniform> u_fixed : FixedData;
@group(0) @binding(1) var rasterSampler    : sampler;
@group(0) @binding(2) var rasterTexture    : texture_2d<f32>;
@group(0) @binding(3) var sdfSampler       : sampler;
@group(0) @binding(4) var sdfTexture       : texture_2d<f32>;
@group(0) @binding(5) var shadowSampler    : sampler;
@group(0) @binding(6) var shadowTexture    : texture_2d<f32>;

fn alphaComposite(foreground: vec4f, background: vec4f) -> vec4f
{
  return vec4f(
    foreground.xyz * foreground.w + background.xyz * background.w * (1.0 - foreground.w),
    max(background.w, foreground.w)
  );
}

struct Output
{
  @builtin(position) position : vec4f,
}

@vertex
fn vs_main(@builtin(vertex_index) vertexIndex : u32) -> Output
{
  let vertices = array(
    vec3f(-1.0, -1.0, 0.0),
    vec3f(-1.0,  1.0, 0.0),
    vec3f( 1.0,  1.0, 0.0),
    vec3f(-1.0, -1.0, 0.0),
    vec3f( 1.0,  1.0, 0.0),
    vec3f( 1.0, -1.0, 0.0),
  );
  return Output(vec4f(vertices[vertexIndex], 1.0));
}

@fragment
fn fs_main(in : Output) -> @location(0) vec4f
{
  let framebufferDimensions = vec2f(u_fixed.framebufferDimensions);
  let textureDimensions = vec2f(u_fixed.textureDimensions);

  let fbUv = in.position.xy / framebufferDimensions;

  let tx = fbUv * textureDimensions;
  let txUv = (floor(tx) + 0.5) / textureDimensions;

  let sdfSample = textureSample(sdfTexture, sdfSampler, txUv);
  let shadowSample = max(textureSample(shadowTexture, shadowSampler, txUv), vec4f(0.1, 0.1, 0.1, 0.0));
  let rasterSample = textureSample(rasterTexture, rasterSampler, fbUv);

  let composite = alphaComposite(
    alphaComposite(sdfSample, shadowSample),
    rasterSample
  );

  var col = composite.xyz;

  col = pow(composite.xyz, vec3f(1.8)); // Gamma correction

  return vec4f(col, 1.0);
}
