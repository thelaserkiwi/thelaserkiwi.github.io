
var wasm;

async function run_jetpack() {
  const framebufferDimensions = { width: 640, height: 360 };
  const sdfTextureDimensions = { width: 160, height: 90 };

  const memory = new WebAssembly.Memory({ initial: 258, maximum: 258 });

  wasm = await WebAssembly.instantiateStreaming(
    fetch("jetpack.wasm", { credentials: "same-origin" }),
    { "env": { "memory": memory } }
  );

  const sdfShaderSource = await loadFile("jetpack.wgsl");
  if (!sdfShaderSource) {
    throw new Error("Failed to load sdf shader.");
  }

  const sdfShadowShaderSource = await loadFile("jetpack_shadow.wgsl");
  if (!sdfShadowShaderSource) {
    throw new Error("Failed to load sdf shadow shader.");
  }

  const rasterShaderSource = await loadFile("raster.wgsl");
  if (!rasterShaderSource) {
    throw new Error("Failed to load raster shader.");
  }

  const compositeShaderSource = await loadFile("composite.wgsl");
  if (!compositeShaderSource) {
    throw new Error("Failed to load composite shader.");
  }

  await run(framebufferDimensions, sdfTextureDimensions, wasm, sdfShaderSource, sdfShadowShaderSource, rasterShaderSource, compositeShaderSource, memory);
}

run_jetpack().then(value => {
  const status = document.getElementById("status");
  status.innerHTML = "<span>Loaded</span>";
}).catch(error => {
  const status = document.getElementById("status");
  status.innerHTML = '<span style="color:red; font-size:16px;">Error: ' + error.message + '</span>';
});
