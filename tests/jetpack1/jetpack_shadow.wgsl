
struct CameraData
{
  projectionMatrix        : mat4x4f,
  inverseProjectionMatrix : mat4x4f,
  viewMatrix              : mat4x4f,
  inverseViewMatrix       : mat4x4f,
}

struct LightData
{
  translation : vec3f,
  colour      : vec3f,
}

struct JetpackData
{
  bbMin             : vec3f,
  bbMax             : vec3f,
  hips              : mat4x4f,
  head              : mat4x4f,
  headphones        : mat4x4f,
  rightHeadphone    : mat4x4f,
  leftHeadphone     : mat4x4f,
  rightHeadphonePad : mat4x4f,
  leftHeadphonePad  : mat4x4f,
  rightEar          : mat4x4f,
  leftEar           : mat4x4f,
  rightFoot         : mat4x4f,
  leftFoot          : mat4x4f,
  rightHand         : mat4x4f,
  leftHand          : mat4x4f,
  rightEye          : mat4x4f,
  leftEye           : mat4x4f,
  leftCheek         : mat4x4f,
  rightCheek        : mat4x4f,
  card              : mat4x4f,
  tail00            : vec3f,
  tail01            : vec3f,
  tail02            : vec3f,
  tail03            : vec3f,
  tail04            : vec3f,
  hipsScale         : vec3f,
  headScale         : vec3f,
  rightEarScale     : vec3f,
  leftEarScale      : vec3f,
  rightHandScale    : vec3f,
  leftHandScale     : vec3f,
  rightFootScale    : vec3f,
  leftFootScale     : vec3f,
  rightEyeScale     : vec3f,
  leftEyeScale      : vec3f,
}

struct BlinnPhongMaterialData
{
  albedoColour     : vec3f,
  ambientStrength  : f32,
  diffuseStrength  : f32,
  specularStrength : f32,
  shininess        : f32,
  transparency     : f32,
}

////////////////////////////////////////////////////////////////////////////////////

struct FixedData
{
  framebufferDimensions : vec2<i32>,
  textureDimensions     : vec2<i32>,
  maxSteps              : u32,
  maxDist               : f32,
  surfDist              : f32,
  normalOffset          : f32,
}

struct VariableData
{
  camera               : CameraData,
  characterCamera      : CameraData,
  lightFill            : LightData,
  lightBack            : LightData,
  lightKey             : LightData,
  jetpack              : JetpackData,
  jetpackBody          : BlinnPhongMaterialData,
  jetpackHeadphones    : BlinnPhongMaterialData,
  jetpackHeadphonePads : BlinnPhongMaterialData,
  jetpackEyes          : BlinnPhongMaterialData,
  jetpackCheeks        : BlinnPhongMaterialData,
  floor                : BlinnPhongMaterialData,
}

////////////////////////////////////////////////////////////////////////////////////

@group(0) @binding(0) var<uniform> u_fixed    : FixedData;
@group(0) @binding(1) var<uniform> u_variable : VariableData;

////////////////////////////////////////////////////////////////////////////////////

const g_softShadowMaxSteps : u32 = 1000u;
const g_softShadowSurfDist : f32 = 0.001;

fn getDistanceFloor(p: vec3f) -> f32
{
  return p.y;
}

fn getDistanceSphere(p: vec3f, r: f32) -> f32
{
  return length(p) - r;
}

fn getDistanceEllipsoid(p: vec3f, r: vec3f) -> f32
{
  let k0 = length(p / r);
  let k1 = length(p / (r * r));
  return k0 * (k0 - 1.0) / k1;
}

fn getDistanceUnion(d: f32, r: f32) -> f32
{
  return min(r, d);
}

fn getTransformedP(p: vec3f, minv: mat4x4f) -> vec3f
{
  return (minv * vec4f(p, 1.0)).xyz;
}

fn testDist(d: f32, r: f32) -> f32
{
  return getDistanceUnion(d, r);
}

fn getDistJetpackBody(p: vec3f) -> f32
{
  return getDistanceUnion(
    getDistanceUnion(
      getDistanceUnion(
        getDistanceEllipsoid(getTransformedP(p, u_variable.jetpack.hips), u_variable.jetpack.hipsScale),
        getDistanceEllipsoid(getTransformedP(p, u_variable.jetpack.head), u_variable.jetpack.headScale),
      ),
      getDistanceUnion(
        getDistanceEllipsoid(getTransformedP(p, u_variable.jetpack.rightHand), u_variable.jetpack.rightHandScale),
        getDistanceEllipsoid(getTransformedP(p, u_variable.jetpack.leftHand), u_variable.jetpack.leftHandScale)
      )
    ),
    getDistanceUnion(
      getDistanceEllipsoid(getTransformedP(p, u_variable.jetpack.rightFoot), u_variable.jetpack.rightFootScale),
      getDistanceEllipsoid(getTransformedP(p, u_variable.jetpack.leftFoot), u_variable.jetpack.leftFootScale)
    )
  );
}

fn getDist(ro: vec3f, rd: vec3f) -> f32
{
  let p = ro + rd;
  var r = getDistJetpackBody(p);
  r = testDist(getDistanceFloor(p), r);
  return r;
}

fn getNormal(p: vec3f) -> vec3f
{
  let e = vec2f(1.0, -1.0) * 0.5773;
  return normalize(
    e.xyy * getDist(p, e.xyy * u_fixed.normalOffset) +
    e.yyx * getDist(p, e.yyx * u_fixed.normalOffset) +
    e.yxy * getDist(p, e.yxy * u_fixed.normalOffset) +
    e.xxx * getDist(p, e.xxx * u_fixed.normalOffset)
  );
}

struct RayMarchResults
{
  t : f32,
  s : bool,
}

fn rayMarch(ro: vec3f, rd: vec3f) -> RayMarchResults
{
  var t = 0.0;
  for (var i = 0u; i < u_fixed.maxSteps; i++)
  {
    let d = getDist(ro, rd * t);
    t += d;
    if (abs(d) < u_fixed.surfDist)
    {
      return RayMarchResults(t, true);
    }
    else if (t > u_fixed.maxDist)
    {
      return RayMarchResults(t, false);
    }
  }
  return RayMarchResults(t, false);
}

fn softShadow(ro: vec3f, rd: vec3f, mint: f32, maxt: f32, k: f32) -> f32
{
  var res = 1.0;
  var t = mint;
  for (var i = 0u; i < g_softShadowMaxSteps && t < maxt; i++)
  {
    let h = getDist(ro, rd * t);
    if (h < g_softShadowSurfDist)
    {
      return 0.0;
    }
    res = min(res, k * h / t);
    t += h;
  }
  return res;
}

fn getShadow(light: LightData, p: vec3f, n: vec3f) -> f32
{
  let surfDist = 0.002;

  let l = normalize(light.translation - p);
  let shadow = softShadow(p + n * surfDist, l, 1.0, 2.0, 1.5);
  return shadow;
}

////////////////////////////////////////////////////////////////////////////////////

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
  let textureDimensions = vec2f(u_fixed.textureDimensions);

  let screenUv = ((in.position.xy / textureDimensions) - 0.5) * vec2f(2.0, -2.0);
  let screenPoint = vec4f(screenUv.x, screenUv.y, 1.0, 1.0);
  let dirEye = u_variable.characterCamera.inverseProjectionMatrix * screenPoint;
  let dirWorld = (u_variable.characterCamera.viewMatrix * vec4f(dirEye.xyz, 0.0)).xyz;
  let rd = normalize(dirWorld);

  let ro = u_variable.characterCamera.viewMatrix[3].xyz; // Point
  let cd = u_variable.characterCamera.viewMatrix[2].xyz; // Z-forward

  var d = rayMarch(ro, rd);

  if (!d.s)
  {
    return vec4f(0.0, 0.0, 0.0, 1.0);
  }

  var p = ro + rd * d.t;
  var n = getNormal(p);

  let l = LightData(vec3f(0.0, 18.0, 18.0), vec3f(1.0, 0.0, 0.0));

  var col = 1.0;
  col *= getShadow(l, p, n);
  // col *= getShadow(u_variable.lightFill, p, n);
  // col *= getShadow(u_variable.lightBack, p, n);
  // col *= getShadow(u_variable.lightKey, p, n);

  return vec4f(col, col, col, 1.0 - col);
}
