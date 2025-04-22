
const keyMap = {
  "a":          0,
  "b":          1,
  "c":          2,
  "d":          3,
  "e":          4,
  "f":          5,
  "g":          6,
  "h":          7,
  "i":          8,
  "j":          9,
  "k":          10,
  "l":          11,
  "m":          12,
  "n":          13,
  "o":          14,
  "p":          15,
  "q":          16,
  "r":          17,
  "s":          18,
  "t":          19,
  "u":          20,
  "v":          21,
  "w":          22,
  "x":          23,
  "y":          24,
  "z":          25,
  "A":          0,
  "B":          1,
  "C":          2,
  "D":          3,
  "E":          4,
  "F":          5,
  "G":          6,
  "H":          7,
  "I":          8,
  "J":          9,
  "K":          10,
  "L":          11,
  "M":          12,
  "N":          13,
  "O":          14,
  "P":          15,
  "Q":          16,
  "R":          17,
  "S":          18,
  "T":          19,
  "U":          20,
  "V":          21,
  "W":          22,
  "X":          23,
  "Y":          24,
  "Z":          25,
  "0":          26,
  "1":          27,
  "2":          28,
  "3":          29,
  "4":          30,
  "5":          31,
  "6":          32,
  "7":          33,
  "8":          34,
  "9":          35,
  "Meta":       36,
  "Control":    37,
  "Alt":        38,
  "Shift":      39,
  "Enter":      40,
  "Escape":     41,
  " ":          42,
  "ArrowUp":    43,
  "ArrowDown":  44,
  "ArrowLeft":  45,
  "ArrowRight": 46,
};

const buttonMap = {
  0: 1,
  1: 2,
  2: 3,
};

async function loadFile(path) {
  const response = await fetch(path);
  const text = await response.text();
  return text;
}

async function run(framebufferDimensions, sdfTextureDimensions, wasm, sdfShaderSource, sdfShadowShaderSource, rasterShaderSource, compositeShaderSource, memory) {
  const data = new DataView(memory.buffer);

  const canvas = document.getElementById("canvas");
  const context = canvas.getContext("webgpu");

  canvas.addEventListener("wheel", function (event) {
    wasm.instance.exports.mouseScroll(event.deltaY);
    event.preventDefault();
  });

  canvas.addEventListener("mousedown", function (event) {
    const button = buttonMap[event.button];
    if (button === undefined) {
      console.warn("Unsupported mouse button %d", event.button);
    } else {
      wasm.instance.exports.mouseButtonPress(button, event.offsetX, event.offsetY);
    }
  });

  canvas.addEventListener("mouseup", function (event) {
    const button = buttonMap[event.button];
    if (button === undefined) {
      console.warn("Unsupported mouse button %d", event.button);
    } else {
      wasm.instance.exports.mouseButtonRelease(button);
    }
  });

  canvas.addEventListener("mouseover", function (event) {
  });

  canvas.addEventListener("mouseout", function (event) {
    wasm.instance.exports.mouseButtonReleaseAll();
    wasm.instance.exports.keyReleaseAll();
  });

  canvas.addEventListener("mousemove", function (event) {
    wasm.instance.exports.mouseMove(event.offsetX, event.offsetY);
  });

  window.addEventListener("keydown", function (event) {
    const key = keyMap[event.key];
    if (key === undefined) {
      console.warn("Unsupported key % (%s)", event.key, event.keyCode);
    } else {
      wasm.instance.exports.keyPress(key);
    }
  });

  window.addEventListener("keyup", function (event) {
    const key = keyMap[event.key];
    if (key === undefined) {
      console.warn("Unsupported key % (%s)", event.key, event.keyCode);
    } else {
      wasm.instance.exports.keyRelease(key);
    }
  });

  wasm.instance.exports.setup()

  data.setInt32(0, framebufferDimensions.width, true);
  data.setInt32(4, framebufferDimensions.height, true);
  data.setInt32(8, sdfTextureDimensions.width, true);
  data.setInt32(12, sdfTextureDimensions.height, true);

  wasm.instance.exports.bind()

  if (!navigator.gpu) {
    throw new Error("WebGPU not supported on this browser.");
  }

  const adapter = await navigator.gpu.requestAdapter();
  if (!adapter) {
    throw new Error("No appropriate GPUAdapter found.");
  }

  const device = await adapter.requestDevice();

  const canvasFormat = navigator.gpu.getPreferredCanvasFormat();
  context.configure({
    device: device,
    format: canvasFormat,
  });

  const fixedBuffer = device.createBuffer({
    label: "Fixed Buffer",
    mappedAtCreation: false,
    size: wasm.instance.exports.getFixedDataSize(),
    usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.UNIFORM
  })

  const sdfShaderMmodule = device.createShaderModule({
    label: "SDF Shader",
    code: sdfShaderSource,
  });

  const sdfPipeline = device.createRenderPipeline({
    label: "SDF Pipeline",
    layout: "auto",
    vertex: {
      module: sdfShaderMmodule,
      entryPoint: "vs_main"
    },
    fragment: {
      module: sdfShaderMmodule,
      entryPoint: "fs_main",
      targets: [{
        format: canvasFormat
      }]
    }
  });

  const sdfVariableBuffer = device.createBuffer({
    label: "SDF Variable Buffer",
    mappedAtCreation: false,
    size: wasm.instance.exports.getVariableDataSize(),
    usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.UNIFORM
  })

  const sdfBindGroup = device.createBindGroup({
    label: "SDF Bind Group",
    layout: sdfPipeline.getBindGroupLayout(0),
    entries: [
      { binding: 0, resource: { buffer: fixedBuffer } },
      { binding: 1, resource: { buffer: sdfVariableBuffer } },
    ],
  });

  const sdfShadowShaderMmodule = device.createShaderModule({
    label: "SDF Shadow Shader",
    code: sdfShadowShaderSource,
  });

  const sdfShadowPipeline = device.createRenderPipeline({
    label: "SDF Shadow Pipeline",
    layout: "auto",
    vertex: {
      module: sdfShadowShaderMmodule,
      entryPoint: "vs_main"
    },
    fragment: {
      module: sdfShadowShaderMmodule,
      entryPoint: "fs_main",
      targets: [{
        format: canvasFormat
      }]
    }
  });

  const sdfShadowBindGroup = device.createBindGroup({
    label: "SDF Shadow Bind Group",
    layout: sdfShadowPipeline.getBindGroupLayout(0),
    entries: [
      { binding: 0, resource: { buffer: fixedBuffer } },
      { binding: 1, resource: { buffer: sdfVariableBuffer } },
    ],
  });

  const rasterShaderMmodule = device.createShaderModule({
    label: "Raster Shader",
    code: rasterShaderSource,
  });

  const rasterPipeline = device.createRenderPipeline({
    label: "Raster Pipeline",
    layout: "auto",
    vertex: {
      module: rasterShaderMmodule,
      entryPoint: "vs_main"
    },
    fragment: {
      module: rasterShaderMmodule,
      entryPoint: "fs_main",
      targets: [{
        format: canvasFormat
      }]
    }
  });

  const rasterBindGroup = device.createBindGroup({
    label: "Raster Bind Group",
    layout: rasterPipeline.getBindGroupLayout(0),
    entries: [
      { binding: 0, resource: { buffer: sdfVariableBuffer } },
    ],
  });

  const compositeShaderMmodule = device.createShaderModule({
    label: "Composite Shader",
    code: compositeShaderSource,
  });

  const compositePipeline = device.createRenderPipeline({
    label: "Composite Pipeline",
    layout: "auto",
    vertex: {
      module: compositeShaderMmodule,
      entryPoint: "vs_main"
    },
    fragment: {
      module: compositeShaderMmodule,
      entryPoint: "fs_main",
      targets: [{
        format: canvasFormat
      }]
    }
  });

  const sdfTexture = device.createTexture({
    label: "SDF Texture",
    size: [ sdfTextureDimensions.width, sdfTextureDimensions.height ],
    dimension: "2d",
    format: canvasFormat,
    usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
  });

  const sdfTextureSampler = device.createSampler({
    magFilter: "nearest",
    minFilter: "nearest",
    addressModeU: "clamp-to-edge",
    addressModeV: "clamp-to-edge",
  });

  const sdfTextureView = sdfTexture.createView();


  const sdfShadowTexture = device.createTexture({
    label: "SDF Shadow Texture",
    size: [ sdfTextureDimensions.width, sdfTextureDimensions.height ],
    dimension: "2d",
    format: canvasFormat,
    usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
  });

  const sdfShadowTextureSampler = device.createSampler({
    magFilter: "nearest",
    minFilter: "nearest",
    addressModeU: "clamp-to-edge",
    addressModeV: "clamp-to-edge",
  });

  const sdfShadowTextureView = sdfShadowTexture.createView();

  const rasterTexture = device.createTexture({
    label: "Raster Texture",
    size: [ framebufferDimensions.width, framebufferDimensions.height ],
    dimension: "2d",
    format: canvasFormat,
    usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
  });

  const rasterTextureSampler = device.createSampler({
    magFilter: "nearest",
    minFilter: "nearest",
    addressModeU: "clamp-to-edge",
    addressModeV: "clamp-to-edge",
  });

  const rasterTextureView = rasterTexture.createView();

  const compositeBindGroup = device.createBindGroup({
    label: "Composite Bind Group",
    layout: compositePipeline.getBindGroupLayout(0),
    entries: [
      { binding: 0, resource: { buffer: fixedBuffer } },
      { binding: 1, resource: rasterTextureSampler },
      { binding: 2, resource: rasterTextureView },
      { binding: 3, resource: sdfTextureSampler },
      { binding: 4, resource: sdfTextureView },
      { binding: 5, resource: sdfShadowTextureSampler },
      { binding: 6, resource: sdfShadowTextureView },
    ],
  });

  device.queue.writeBuffer(fixedBuffer, 0, memory.buffer, 0, wasm.instance.exports.getFixedDataSize());
  
  previousTime = Date.now();

  async function draw(timestamp) {
    const currentTime = Date.now();
    const deltaTime = (currentTime - previousTime) / 1000;
    wasm.instance.exports.setFps(deltaTime);
    previousTime = currentTime;

    wasm.instance.exports.compute()

    device.queue.writeBuffer(sdfVariableBuffer, 0, memory.buffer, wasm.instance.exports.getFixedDataSize(), wasm.instance.exports.getVariableDataSize());

    requestAnimationFrame(draw);

    const commandEncoder = device.createCommandEncoder();

    const sdfPassEncoder = commandEncoder.beginRenderPass({
      label: "SDF Render Pass",
      colorAttachments: [{
        view: sdfTextureView,
        loadOp: "clear",
        storeOp: "store",
        clearValue: { r: 0.0, g: 1.0, b: 0.0, a: 1.0 },
      }]
    });

    sdfPassEncoder.setPipeline(sdfPipeline);
    sdfPassEncoder.setBindGroup(0, sdfBindGroup);
    sdfPassEncoder.draw(6);

    sdfPassEncoder.end();

    const sdfShadowPassEncoder = commandEncoder.beginRenderPass({
      label: "SDF Shadow Render Pass",
      colorAttachments: [{
        view: sdfShadowTextureView,
        loadOp: "clear",
        storeOp: "store",
        clearValue: { r: 0.0, g: 1.0, b: 0.0, a: 1.0 },
      }]
    });

    sdfShadowPassEncoder.setPipeline(sdfShadowPipeline);
    sdfShadowPassEncoder.setBindGroup(0, sdfShadowBindGroup);
    sdfShadowPassEncoder.draw(6);

    sdfShadowPassEncoder.end();

    const rasterPassEncoder = commandEncoder.beginRenderPass({
      label: "Raster Render Pass",
      colorAttachments: [{
        view: rasterTextureView,
        loadOp: "clear",
        storeOp: "store",
        clearValue: { r: 0.0, g: 1.0, b: 0.0, a: 1.0 },
      }]
    });

    rasterPassEncoder.setPipeline(rasterPipeline);
    rasterPassEncoder.setBindGroup(0, rasterBindGroup);
    rasterPassEncoder.draw(6);

    rasterPassEncoder.end();

    const compositePassEncoder = commandEncoder.beginRenderPass({
      label: "Composite Render Pass",
      colorAttachments: [{
        view: context.getCurrentTexture().createView(),
        loadOp: "clear",
        storeOp: "store",
        clearValue: { r: 0.0, g: 1.0, b: 0.0, a: 1.0 },
      }]
    });

    compositePassEncoder.setPipeline(compositePipeline);
    compositePassEncoder.setBindGroup(0, compositeBindGroup);
    compositePassEncoder.draw(6);

    compositePassEncoder.end();

    device.queue.submit([commandEncoder.finish()]);
  };

  requestAnimationFrame(draw);
}
