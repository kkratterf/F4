// The hero background: a flowing, grainy gradient drawn with WebGL, after
// React Bits' "Grainient" (reactbits.dev/backgrounds/grainient). Plain
// WebGL, no library, so the site keeps its no-build-step rule.
//
// Usage: <canvas data-grainient data-colors="#ffa726,#ff4d1f,#1c0805">.
// Without WebGL the canvas stays empty and the CSS gradient behind it shows.
(function () {
  var canvas = document.querySelector("canvas[data-grainient]");
  if (!canvas) return;
  var gl = canvas.getContext("webgl", { antialias: false, alpha: false, premultipliedAlpha: false });
  if (!gl) return;

  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  var vertex = [
    "attribute vec2 position;",
    "void main() { gl_Position = vec4(position, 0.0, 1.0); }"
  ].join("\n");

  // Noise turns the plane, a sine warp bends it, three colours blend across
  // it, then grain, contrast and saturation finish it.
  var fragment = [
    "precision highp float;",
    "uniform vec2 uResolution;",
    "uniform float uTime;",
    "uniform vec3 uColor1;",
    "uniform vec3 uColor2;",
    "uniform vec3 uColor3;",
    "const float timeSpeed = 0.25;",
    "const float warpFrequency = 5.0;",
    "const float warpSpeed = 2.0;",
    "const float warpAmplitude = 50.0;",
    "const float blendSoftness = 0.05;",
    "const float rotationAmount = 500.0;",
    "const float noiseScale = 2.0;",
    "const float grainAmount = 0.08;",
    "const float grainScale = 2.0;",
    "const float contrast = 1.4;",
    "const float saturation = 1.0;",
    "const float zoom = 0.9;",
    "mat2 rot(float a) { float s = sin(a), c = cos(a); return mat2(c, -s, s, c); }",
    "vec2 hash(vec2 p) {",
    "  p = vec2(dot(p, vec2(2127.1, 81.17)), dot(p, vec2(1269.5, 283.37)));",
    "  return fract(sin(p) * 43758.5453);",
    "}",
    "float noise(vec2 p) {",
    "  vec2 i = floor(p), f = fract(p);",
    "  vec2 u = f * f * (3.0 - 2.0 * f);",
    "  float n = mix(",
    "    mix(dot(-1.0 + 2.0 * hash(i), f), dot(-1.0 + 2.0 * hash(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),",
    "    mix(dot(-1.0 + 2.0 * hash(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)), dot(-1.0 + 2.0 * hash(i + vec2(1.0)), f - vec2(1.0)), u.x),",
    "    u.y);",
    "  return 0.5 + 0.5 * n;",
    "}",
    "void main() {",
    "  float t = uTime * timeSpeed;",
    "  vec2 uv = gl_FragCoord.xy / uResolution;",
    "  float ratio = uResolution.x / uResolution.y;",
    "  vec2 p = (uv - 0.5) / zoom;",
    "  float degree = noise(vec2(t * 0.1, p.x * p.y) * noiseScale);",
    "  p.y /= ratio;",
    "  p *= rot(radians((degree - 0.5) * rotationAmount + 180.0));",
    "  p.y *= ratio;",
    "  float w = t * warpSpeed;",
    "  p.x += sin(p.y * warpFrequency + w) / warpAmplitude;",
    "  p.y += sin(p.x * warpFrequency * 1.5 + w) / (warpAmplitude * 0.5);",
    "  float e0 = -0.3 - blendSoftness, e1 = 0.2 + blendSoftness;",
    "  vec3 a = mix(uColor3, uColor2, smoothstep(e0, e1, p.x));",
    "  vec3 b = mix(uColor2, uColor1, smoothstep(e0, e1, p.x));",
    "  vec3 col = mix(a, b, smoothstep(0.5 + blendSoftness, -0.3 - blendSoftness, p.y));",
    "  float grain = fract(sin(dot(uv * grainScale * uResolution / 2.0, vec2(12.9898, 78.233))) * 43758.5453);",
    "  col += (grain - 0.5) * grainAmount;",
    "  col = (col - 0.5) * contrast + 0.5;",
    "  float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));",
    "  col = clamp(mix(vec3(luma), col, saturation), 0.0, 1.0);",
    "  gl_FragColor = vec4(col, 1.0);",
    "}"
  ].join("\n");

  function compile(type, source) {
    var shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    return gl.getShaderParameter(shader, gl.COMPILE_STATUS) ? shader : null;
  }

  var vs = compile(gl.VERTEX_SHADER, vertex);
  var fs = compile(gl.FRAGMENT_SHADER, fragment);
  if (!vs || !fs) return;
  var program = gl.createProgram();
  gl.attachShader(program, vs);
  gl.attachShader(program, fs);
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) return;
  gl.useProgram(program);

  var buffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
  var position = gl.getAttribLocation(program, "position");
  gl.enableVertexAttribArray(position);
  gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);

  function rgb(hex) {
    var n = parseInt(hex.replace("#", ""), 16);
    return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
  }
  var colors = (canvas.dataset.colors || "#ffa726,#ff4d1f,#1c0805").split(",");
  gl.uniform3fv(gl.getUniformLocation(program, "uColor1"), rgb(colors[0]));
  gl.uniform3fv(gl.getUniformLocation(program, "uColor2"), rgb(colors[1]));
  gl.uniform3fv(gl.getUniformLocation(program, "uColor3"), rgb(colors[2]));
  var uResolution = gl.getUniformLocation(program, "uResolution");
  var uTime = gl.getUniformLocation(program, "uTime");

  // Half resolution is plenty for a blurred, grainy gradient and keeps
  // the page light on laptops.
  function resize() {
    var w = Math.max(1, Math.round(canvas.clientWidth * 0.5));
    var h = Math.max(1, Math.round(canvas.clientHeight * 0.5));
    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w;
      canvas.height = h;
      gl.viewport(0, 0, w, h);
    }
    gl.uniform2f(uResolution, w, h);
  }

  var start = performance.now();
  var visible = true;
  function frame(now) {
    resize();
    gl.uniform1f(uTime, (now - start) / 1000);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    canvas.classList.add("on");
    if (!reduce && visible) requestAnimationFrame(frame);
  }

  // Stop drawing when the hero is off screen or the tab is hidden.
  if ("IntersectionObserver" in window) {
    new IntersectionObserver(function (entries) {
      var was = visible;
      visible = entries[0].isIntersecting && !document.hidden;
      if (visible && !was && !reduce) requestAnimationFrame(frame);
    }).observe(canvas);
  }
  document.addEventListener("visibilitychange", function () {
    var was = visible;
    visible = !document.hidden;
    if (visible && !was && !reduce) requestAnimationFrame(frame);
  });
  window.addEventListener("resize", function () {
    if (reduce) requestAnimationFrame(frame);
  });

  requestAnimationFrame(frame);
})();
