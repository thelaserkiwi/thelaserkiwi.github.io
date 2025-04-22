
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
  tail00            : vec3f,
  tail01            : vec3f,
  tail02            : vec3f,
  tail03            : vec3f,
  tail04            : vec3f,
  rightFootScale    : vec3f,
  leftFootScale     : vec3f,
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

// @group(0) @binding(0) var<uniform> u_fixed    : FixedData;
@group(0) @binding(0) var<uniform> u_variable : VariableData;

////////////////////////////////////////////////////////////////////////////////////

fn blinnPhongIllumination(light: LightData, material: BlinnPhongMaterialData, modelPosition: vec3f, modelNormal: vec3f, viewDirection: vec3f) -> vec3f
{
  let lightDirection = normalize(light.translation - modelPosition);

  let ambient = light.colour * material.albedoColour * material.ambientStrength;

  let diff = max(dot(modelNormal, lightDirection), 0.0);
  let diffuse =  diff * material.diffuseStrength;

  let reflectDirection = reflect(lightDirection, modelNormal);
  let spec = pow(max(dot(viewDirection, reflectDirection), 0.0), material.shininess);
  let specular = spec * material.specularStrength;

  return ambient + diffuse + specular;
}

////////////////////////////////////////////////////////////////////////////////////

struct Output
{
  @builtin(position) position: vec4f,
  @location(0) modelPosition: vec3f,
  @location(1) modelNormal: vec3f,
  @location(2) viewPosition: vec3f,
};

@vertex
fn vs_main(@builtin(vertex_index) vertexIndex : u32) -> Output
{
  let vertices = array(
    vec3f(-1000.0, 0.0,  1000.0),
    vec3f( 1000.0, 0.0,  1000.0),
    vec3f( 1000.0, 0.0, -1000.0),
    vec3f( 1000.0, 0.0, -1000.0),
    vec3f(-1000.0, 0.0, -1000.0),
    vec3f(-1000.0, 0.0,  1000.0),
  );

  return Output(
    u_variable.camera.projectionMatrix * u_variable.camera.inverseViewMatrix * vec4f(vertices[vertexIndex], 1.0),
    vertices[vertexIndex],
    vec3f(0.0, 1.0, 0.0),
    vec3f(
      u_variable.camera.inverseViewMatrix[3][0],
      u_variable.camera.inverseViewMatrix[3][1],
      u_variable.camera.inverseViewMatrix[3][2]
    )
  );
}

@fragment
fn fs_main(in : Output) -> @location(0) vec4f
{
  let material = u_variable.floor;

  let modelPosition = in.modelPosition;
  let modelNormal = normalize(in.modelNormal);
  let viewPosition = in.viewPosition;

  let viewDirection = normalize(viewPosition - modelPosition);

  var col = vec3f(0.0);

  col = material.albedoColour;
  // col += blinnPhongIllumination(u_variable.lightFill, material, modelPosition, modelNormal, viewDirection);
  // col += blinnPhongIllumination(u_variable.lightBack, material, modelPosition, modelNormal, viewDirection);
  // col += blinnPhongIllumination(u_variable.lightKey, material, modelPosition, modelNormal, viewDirection);

  // col = pow(col, vec3f(2.2)); // Gamma correction

  return vec4f(col, 1.0);
}
