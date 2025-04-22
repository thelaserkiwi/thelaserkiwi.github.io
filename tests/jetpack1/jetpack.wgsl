
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

fn squaredLength(v: vec3f) -> f32
{
  return dot(v, v);
}

fn squaredLength2(v: vec2f) -> f32
{
  return dot(v, v);
}

fn linearRemap(value: f32, fromLow: f32, fromUp: f32, toLow: f32, toUp: f32) -> f32
{
  return toLow + (value - fromLow) * ((toUp - toLow) / (fromUp - fromLow));
}

fn easeOutQuad(x: f32) -> f32
{
  return 1.0 - (1.0 - x) * (1.0 - x);
}

////////////////////////////////////////////////////////////////////////////////////

fn intersectRayBoundingBox(ro: vec3f, rd: vec3f, minPoint: vec3f, maxPoint: vec3f) -> bool
{
  var tmin = 0.0;
  var tmax = u_fixed.maxDist;

  for (var i = 0u; i < 3u; i++)
  {
    if (abs(rd[i]) < 0.0001)
    {
      if (ro[i] < minPoint[i] || ro[i] > maxPoint[i])
      {
        return false;
      }
    }
    else
    {
      let ood = 1.0 / rd[i];
      var t1 = (minPoint[i] - ro[i]) * ood;
      var t2 = (maxPoint[i] - ro[i]) * ood;
      if (t1 > t2)
      {
        let tmpT1 = t1;
        t1 = t2;
        t2 = tmpT1;
      }
      tmin = max(tmin, t1);
      tmax = min(tmax, t2);
      if (tmin > tmax)
      {
        return false;
      }
    }
  }

  return true;
}

fn getDistanceHeart2d(p: vec2f) -> f32
{
  var p2 = p;
  p2.x = abs(p.x);

  if (p2.y + p2.x > 1.0)
  {
    return sqrt(squaredLength2(p2 - vec2(0.25, 0.75))) - sqrt(2.0) / 4.0;
  }

  return sqrt(min(squaredLength2(p2 - vec2(0.0, 1.0)), squaredLength2(p2 - 0.5 * max(p2.x + p2.y, 0.0)))) * sign(p2.x - p2.y);
}

fn getDistanceEllipsoid(p: vec3f, r: vec3f) -> f32
{
  let k0 = length(p / r);
  let k1 = length(p / (r * r));
  return k0 * (k0 - 1.0) / k1;
}

fn getDistanceBox(p: vec3f, b: vec3f) -> f32
{
  let q = abs(p) - b;
  return length(max(q, vec3f(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
}

fn getDistanceRoundCylinder(p: vec3f, h: f32, r: f32, s: f32) -> f32
{
  let d = abs(vec2f(length(p.xz), p.y)) - vec2f(r, h) + s;
  return min(max(d.x, d.y), 0.0) + length(max(d, vec2f(0.0))) - s;
}

fn getDistanceCappedTorus(p: vec3f, c: f32, ra: f32, r: f32) -> f32
{
  let d = radians(189.0) * c;
  let sc = vec2f(vec2(sin(d), cos(d)));
  let p2 = vec3f(abs(p.x), p.y, p.z);
  let k = select(length(p2.xy), dot(p2.xy, sc), sc.y * p2.x > sc.x * p2.y);
  return sqrt(squaredLength(p2) + ra * ra - 2.0 * ra * k) - r;
}

fn det(a: vec2f, b: vec2f) -> f32
{
  return a.x*b.y-b.x*a.y;
}

fn getDistanceQuadraticBezier(p: vec3f, va: vec3f, vb: vec3f, vc: vec3f) -> vec4f
{
  let w = normalize(cross(vc - vb, va - vb));
  let u = normalize(vc - vb);
  let v = cross(w, u);

  let m = vec2f(dot(va - vb, u), dot(va - vb, v));
  let n = vec2f(dot(vc - vb, u), dot(vc - vb, v));
  let q = vec3f(dot(p - vb, u), dot(p - vb, v), dot(p - vb, w));

  let mn = det(m, n);
  let mq = det(m, q.xy);
  let nq = det(n, q.xy);

  let g = (nq + mq + mn) * n + (nq + mq - mn) * m;
  let f = (nq - mq + mn) * (nq - mq + mn) + 4.0 * mq * nq;
  let z = 0.5 * f * vec2f(-g.y, g.x) / dot(g, g);
  let t = clamp(0.5 + 0.5 * (det(z - q.xy, m + n)) / mn, 0.0, 1.0);
  let cp = m * (1.0 - t) * (1.0 - t) + n * t * t - q.xy;

  let d2 = dot(cp, cp);

  return vec4f(sqrt(d2 + q.z * q.z), t, q.z, -sign(f) * sqrt(d2));
}

fn getDistanceUnion(d: f32, r: f32) -> f32
{
  return min(r, d);
}

fn getDistanceSmoothUnion(d1: f32, d2: f32, k: f32) -> f32
{
  let h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
  return mix(d2, d1, h) - k * h * (1.0 - h);
}

fn getDistanceSmoothExpoential(a: f32, b: f32, k: f32) -> f32
{
  let k2 = k * 1.0;
  let r = exp2(-a / k2) + exp2(-b / k2);
  return -k2 * log2(r);
}

fn getDistanceSmoothCirular(a: f32, b: f32, k: f32) -> f32
{
  let k2 = k * (1.0 / (1.0 - sqrt(0.5)));
  let h = max(k2 - abs(a - b), 0.0) / k2;
  return min(a, b) - k2 * 0.5 * (1.0 + h - sqrt(1.0 - h * (h - 2.0)));
}

fn getTransformedP(p: vec3f, minv: mat4x4f) -> vec3f
{
  return (minv * vec4f(p, 1.0)).xyz;
}

struct DistResults
{
  d: f32,
  i: u32,
  m: u32,
};

fn testDist(d: f32, r: f32) -> f32
{
  return getDistanceUnion(d, r);
}

fn testDistAndMaterial(d: f32, i: u32, m: u32, r: DistResults) -> DistResults
{
  if (d < r.d)
  {
    return DistResults(d, i, m);
  }
  else
  {
    return r;
  }
}

fn getDistJetpackBody(p: vec3f) -> f32
{
  return getDistanceSmoothExpoential(
    getDistanceSmoothExpoential(
      getDistanceSmoothExpoential(
        getDistanceSmoothCirular(
          getDistanceEllipsoid(getTransformedP(p, u_variable.jetpack.hips), u_variable.jetpack.hipsScale),
          getDistanceSmoothExpoential(
            getDistanceEllipsoid(getTransformedP(p, u_variable.jetpack.head), u_variable.jetpack.headScale),
            getDistanceSmoothExpoential(
              getDistanceEllipsoid(getTransformedP(p, u_variable.jetpack.rightEar), u_variable.jetpack.rightEarScale),
              getDistanceEllipsoid(getTransformedP(p, u_variable.jetpack.leftEar), u_variable.jetpack.leftEarScale),
              0.1 // Ears
            ),
            1.0 // Head-ears
          ),
          0.5 // Body-head
        ),
        getDistanceSmoothUnion(
          getDistanceEllipsoid(getTransformedP(p, u_variable.jetpack.rightHand), u_variable.jetpack.rightHandScale),
          getDistanceEllipsoid(getTransformedP(p, u_variable.jetpack.leftHand), u_variable.jetpack.leftHandScale),
          0.1
        ),
        0.3 // Body-arms
      ),
      getDistanceSmoothExpoential(
        getDistanceEllipsoid(getTransformedP(p, u_variable.jetpack.rightFoot), u_variable.jetpack.rightFootScale),
        getDistanceEllipsoid(getTransformedP(p, u_variable.jetpack.leftFoot), u_variable.jetpack.leftFootScale),
        0.1
      ),
      0.4 // Body-legs
    ),
    getDistanceUnion(
      getDistanceQuadraticBezier(p, u_variable.jetpack.tail00, u_variable.jetpack.tail01, u_variable.jetpack.tail02).x - 0.5,
      getDistanceQuadraticBezier(p, u_variable.jetpack.tail02, u_variable.jetpack.tail03, u_variable.jetpack.tail04).x - 0.5
    ),
    0.2 // Body-tail
  );
}

fn getDistJetpackEyes(p: vec3f) -> f32
{
  let res = u_variable.jetpack.rightEyeScale;
  let les = u_variable.jetpack.leftEyeScale;

  return getDistanceUnion(
    getDistanceRoundCylinder(getTransformedP(p, u_variable.jetpack.rightEye), res.x, res.y, res.z),
    getDistanceRoundCylinder(getTransformedP(p, u_variable.jetpack.leftEye), les.x, les.y, les.z)
  );
}

fn getDistJetpackCheeks(p: vec3f) -> f32
{
  return getDistanceUnion(
    getDistanceRoundCylinder(getTransformedP(p, u_variable.jetpack.rightCheek), 0.5, 0.3, 0.5),
    getDistanceRoundCylinder(getTransformedP(p, u_variable.jetpack.leftCheek), 0.5, 0.3, 0.5)
  );
}

fn getDistJetpackHeadphones(p: vec3f) -> f32
{
  return getDistanceUnion(
    getDistanceCappedTorus(getTransformedP(p, u_variable.jetpack.headphones), 0.4, 3.5, 0.8),
    getDistanceUnion(
      getDistanceRoundCylinder(getTransformedP(p, u_variable.jetpack.rightHeadphone), 0.5, 1.2, 0.5),
      getDistanceRoundCylinder(getTransformedP(p, u_variable.jetpack.leftHeadphone), 0.5, 1.2, 0.5)
    )
  );
}

fn getDistJetpackHeadphonePads(p: vec3f) -> f32
{
  return getDistanceUnion(
    getDistanceEllipsoid(getTransformedP(p, u_variable.jetpack.rightHeadphonePad), vec3f(1.0, 1.5, 1.2)),
    getDistanceEllipsoid(getTransformedP(p, u_variable.jetpack.leftHeadphonePad), vec3f(1.0, 1.5, 1.2))
  );
}

fn getDistJetpackCard(p: vec3f) -> f32
{
  return getDistanceBox(getTransformedP(p, u_variable.jetpack.card), vec3f(2.5, 1.8, 0.05));
}

fn getDist(ro: vec3f, rd: vec3f) -> f32
{
  let p = ro + rd;
  var r = getDistJetpackBody(p);
  r = testDist(getDistJetpackEyes(p), r);
  r = testDist(getDistJetpackCheeks(p), r);
  r = testDist(getDistJetpackHeadphones(p), r);
  r = testDist(getDistJetpackHeadphonePads(p), r);
  r = testDist(getDistJetpackCard(p), r);
  return r;
}

fn getDistAndMaterial(ro: vec3f, rd: vec3f) -> DistResults
{
  let p = ro + rd;
  var r = DistResults(       getDistJetpackBody(p),          1u, 1u);
  r = testDistAndMaterial(   getDistJetpackEyes(p),          2u, 2u, r);
  r = testDistAndMaterial(   getDistJetpackCheeks(p),        3u, 5u, r);
  r = testDistAndMaterial(   getDistJetpackHeadphones(p),    4u, 3u, r);
  r = testDistAndMaterial(   getDistJetpackHeadphonePads(p), 5u, 4u, r);
  r = testDistAndMaterial(   getDistJetpackCard(p),          6u, 6u, r);
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
  i : u32,
  m : u32,
  s : bool,
}

fn rayMarch(ro: vec3f, rd: vec3f, side: f32) -> RayMarchResults
{
  var t = 0.0;
  for (var i = 0u; i < u_fixed.maxSteps; i++)
  {
    let h = getDistAndMaterial(ro, rd * t);
    t += h.d * side;
    if (abs(h.d) < u_fixed.surfDist)
    {
      return RayMarchResults(t, h.i, h.m, true);
    }
    else if (t > u_fixed.maxDist)
    {
      return RayMarchResults(t, h.i, h.m, false);
    }
  }
  return RayMarchResults(t, 0u, 0u, false);
}

const X4 : f32   = 1.1673039782614187;
const H4 : vec4f = vec4f(1.0 / X4, 1.0 / (X4 * X4), 1.0 / (X4 * X4 * X4), 1.0 / (X4 * X4 * X4 * X4));

fn ambientOcclusion(p: vec3f, n: vec3f) -> f32
{
  var ao = 0.0;
  let off = 0.0; // Add noise here
  var k = vec4f(0.7012912, 0.3941462, 0.8294585, 0.109841) + off;
  for (var i = 0u; i < 16u; i++)
  {
    k = fract(k + H4);
    let h = k.w * 0.1;
    var ap = (n + normalize(-1.0 + 2.0 * k.xyz)) * h;
    let d = getDist(p, ap);
    ao += max(0.0, h - d);
    if (ao > 16.0)
    {
      break;
    }
  }
  ao /= 16.0;
  return clamp(1.0 - ao * 24.0, 0.0, 1.0);
}

struct LightTerms
{
  diffuseStrength  : f32,
  specularStrength : f32,
}

fn getLight(light: LightData, ro: vec3f, p: vec3f, n: vec3f, cd: vec3f) -> LightTerms
{
  let l = normalize(light.translation - p);
  let v = normalize(ro - p);
  let h = normalize(l + v);

  let diffuseStrength = clamp(dot(n, l), 0.0, 1.0);
  let specularStrength = clamp(dot(n, h), 0.0, 1.0);

  return LightTerms(diffuseStrength, specularStrength);
}

fn rimlight(cd: vec3f, n: vec3f) -> f32
{
  let rimLightPower = 8.0;

  var rimLightIntensity = dot(cd, n);
  rimLightIntensity = 1.0 - rimLightIntensity;
  rimLightIntensity = max(0.0, rimLightIntensity);

  rimLightIntensity = pow(rimLightIntensity, rimLightPower);

  return rimLightIntensity;
}

fn blinnPhongIllumination(lightTerms: LightTerms, light: LightData, material: BlinnPhongMaterialData) -> vec3f
{
  let diffuseComponent = lightTerms.diffuseStrength * light.colour;
  let specularComponent = vec3(max(pow(lightTerms.specularStrength, material.shininess), 0.0));

  let ambient = light.colour * material.albedoColour * material.ambientStrength;
  let diffuse = light.colour * lightTerms.diffuseStrength * material.diffuseStrength * diffuseComponent;
  let specular = light.colour * lightTerms.specularStrength * material.specularStrength * specularComponent;

  return ambient + diffuse + specular;
}

fn getMaterial(m: u32) -> BlinnPhongMaterialData
{
  var material = BlinnPhongMaterialData(vec3f(0.4, 0.9, 1.0), 0.2, 0.7, 0.2, 8.0, 1.0);
  if (m == 1u) // Jetpack body
  {
    material = u_variable.jetpackBody;
  }
  else if (m == 2u) // Jetpack eyes
  {
    material = u_variable.jetpackEyes;
  }
  else if (m == 3u) // Jetpack headphones
  {
    material = u_variable.jetpackHeadphones;
  }
  else if (m == 4u) // Jetpack headphone pads
  {
    material = u_variable.jetpackHeadphonePads;
  }
  else if (m == 5u) // Jetpack cheeks
  {
    material = u_variable.jetpackCheeks;
  }
  else if (m == 6u) // Card
  {
    material = BlinnPhongMaterialData(vec3f(1.0, 0.95, 1.0), 0.7, 0.2, 0.2, 2.0, 1.0);
  }
  return material;
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

  if (!intersectRayBoundingBox(ro, rd, u_variable.jetpack.bbMin, u_variable.jetpack.bbMax))
  {
    return vec4f(0.0);
  }

  var col = vec3f(0.0);

  var side = 1.0;
  var d = rayMarch(ro, rd, side);

  if (!d.s)
  {
    return vec4f(0.0);
  }

  var p = ro + rd * d.t;

  var n = getNormal(p);
  var m = d.m;

  var material = getMaterial(m);

  if (m == 6u) // Card
  {
    let r = 2.5 / 1.8;
    let lp = p - u_variable.jetpack.card[3].xyz;
    let uv = vec2f(linearRemap(lp.x, -2.5, 2.5, -r, r), linearRemap(lp.y, -1.8, 1.8, -1.0, 1.0));
    let d = getDistanceHeart2d(uv + vec2f(0.0, 0.5));
    if (d <= 0.0)
    {
      material.albedoColour = vec3f(0.9, 0.0, 0.0);
    }
  }

  let lightFill = getLight(u_variable.lightFill, ro, p, n, cd);
  col += blinnPhongIllumination(lightFill, u_variable.lightFill, material);

  let lightBack = getLight(u_variable.lightBack, ro, p, n, cd);
  col += blinnPhongIllumination(lightBack, u_variable.lightBack, material);

  let lightKey= getLight(u_variable.lightKey, ro, p, n, cd);
  col += blinnPhongIllumination(lightKey, u_variable.lightKey, material);

  let occlusion = ambientOcclusion(p, n);
  col *= easeOutQuad(occlusion);

  let rimlight = rimlight(cd, n);
  col += rimlight;

  // col = pow(col, vec3f(2.2)); // Gamma correction

  return vec4f(col, 1.0);
}
