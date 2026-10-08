-- Deferred 2D renderer.
--
-- World pass  : sprites are drawn into four canvases at once (MRT):
--               albedo, normal, emissive, height.
-- Light pass  : one full-screen shader accumulates ambient + point/spot
--               lights with normal mapping and soft height-field shadows,
--               adds emissive and a little "air glow" around bulbs.
-- Post        : moonshine chain (bloom, desaturate, blur, chroma, vignette,
--               film grain).
-- Present     : sharp-bilinear upscale (nearest to the next integer scale,
--               then linear down to the window) so pixels stay crisp at any
--               window size.
local moonshine = require("lib.moonshine")

local R = {}

R.W, R.H = 480, 270
R.UIW, R.UIH = 960, 540
R.MAXL = 32

local GBUFFER_SRC = [[
uniform Image MainTex;
uniform Image u_normal;
uniform Image u_height;
uniform Image u_emit;
uniform float u_baseH;
uniform float u_emitScale;
uniform float u_mode;      // 0 sprite, 1 flat colour, 2 albedo-only decal
uniform vec3  u_flatN;
uniform float u_flatH;
uniform vec3  u_flatE;
uniform float u_flipX;

void effect() {
  vec2 uv = VaryingTexCoord.xy;
  vec4 c = Texel(MainTex, uv) * VaryingColor;
  if (u_mode > 1.5) {
    love_Canvases[0] = vec4(0.0, 0.0, 0.0, c.a);
    love_Canvases[1] = vec4(0.0);
    love_Canvases[2] = vec4(0.0);
    love_Canvases[3] = vec4(0.0);
    return;
  }
  if (c.a < 0.5) discard;
  vec3 n; float h; vec3 e;
  if (u_mode > 0.5) {
    n = u_flatN * 0.5 + 0.5;
    h = u_flatH;
    e = u_flatE * c.rgb;
  } else {
    n = Texel(u_normal, uv).rgb;
    if (u_flipX > 0.5) n.x = 1.0 - n.x;
    h = Texel(u_height, uv).r * 255.0;
    e = Texel(u_emit, uv).rgb * u_emitScale;
  }
  love_Canvases[0] = vec4(c.rgb, 1.0);
  love_Canvases[1] = vec4(n, 1.0);
  love_Canvases[2] = vec4(e, 1.0);
  love_Canvases[3] = vec4(clamp((h + u_baseH) / 255.0, 0.0, 1.0), 0.0, 0.0, 1.0);
}
]]

local LIGHT_SRC = [[
#define MAXL 32
#define STEPS 18
uniform Image u_normal;
uniform Image u_height;
uniform Image u_emit;
uniform vec2  u_size;
uniform vec3  u_ambient;
uniform int   u_count;
uniform vec4  u_lpos[MAXL];   // ground x, ground y, height z, radius
uniform vec4  u_lcol[MAXL];   // rgb * intensity
uniform vec4  u_ldir[MAXL];   // dir.xy, cos(outer), isSpot
uniform vec4  u_lmisc[MAXL];  // shadows, halo, -, -
uniform float u_saturation;
uniform vec3  u_tint;
uniform float u_exposure;

float hAt(vec2 q) { return Texel(u_height, q / u_size).r * 255.0; }

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
  vec3 alb = Texel(tex, uv).rgb;
  vec3 n = normalize(Texel(u_normal, uv).rgb * 2.0 - 1.0);
  float h = Texel(u_height, uv).r * 255.0;
  vec3 emi = Texel(u_emit, uv).rgb;
  vec2 p = uv * u_size;
  vec3 wp = vec3(p.x, p.y + h, h);

  vec3 acc = u_ambient * (0.55 + 0.45 * clamp(n.z, 0.0, 1.0));
  vec3 air = vec3(0.0);
  for (int i = 0; i < MAXL; i++) {
    if (i >= u_count) break;
    vec4 lp = u_lpos[i];
    vec4 lc = u_lcol[i];
    vec4 ld = u_ldir[i];
    vec4 lm = u_lmisc[i];
    vec2 bulb = vec2(lp.x, lp.y - lp.z);
    if (lm.y > 0.0) {
      float hd = length(p - bulb) / (lp.w * 0.42);
      air += lc.rgb * lm.y * pow(max(1.0 - hd, 0.0), 3.0);
    }
    vec3 L = vec3(lp.x, lp.y, lp.z) - wp;
    float d = length(L);
    if (d >= lp.w) continue;
    vec3 Ld = L / max(d, 0.001);
    float x = d / lp.w;
    float att = 1.0 - x * x;
    att = att * att / (1.0 + 4.0 * x * x);
    if (ld.w > 0.5) {
      vec2 dirTo = -L.xy / max(length(L.xy), 0.001);
      float c = dot(dirTo, ld.xy);
      float near = clamp(1.0 - length(L.xy) / 10.0, 0.0, 1.0);
      att *= max(smoothstep(ld.z, ld.z + 0.14, c), near * 0.6);
    }
    float diff = clamp(dot(n, Ld) * 0.78 + 0.22, 0.0, 1.0);
    if (att * diff < 0.002) continue;
    if (lm.x > 0.5) {
      float occ = 0.0;
      // stop a few pixels short of the bulb so lamps don't shadow themselves
      float tEnd = clamp(1.0 - lm.z / max(length(bulb - p), 0.001), 0.0, 1.0);
      for (int s = 1; s < STEPS; s++) {
        float t = float(s) / float(STEPS) * tEnd;
        vec2 q = mix(p, bulb, t);
        float rh = mix(h, lp.z, t);
        occ = max(occ, smoothstep(1.0, 5.0, hAt(q) - rh));
      }
      att *= 1.0 - occ * 0.93;
    }
    acc += lc.rgb * att * diff;
  }
  vec3 lit = alb * acc * u_exposure;
  lit = vec3(1.0) - exp(-lit * 1.15);
  vec3 col = lit + emi + air;
  float l = dot(col, vec3(0.299, 0.587, 0.114));
  col = mix(vec3(l), col, u_saturation) * u_tint;
  return vec4(col, 1.0);
}
]]

-- 9-tap separable gaussian (linear-sampling offsets) whose spread is a
-- uniform: unlike moonshine's gaussianblur it never recompiles and stays
-- valid for any strength.
local function blurEffect()
  local shader = love.graphics.newShader([[
    extern vec2 direction;
    extern float spread;
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
      vec2 o1 = direction * 1.3846153846 * spread;
      vec2 o2 = direction * 3.2307692308 * spread;
      vec4 c = Texel(tex, tc) * 0.2270270270;
      c += (Texel(tex, tc + o1) + Texel(tex, tc - o1)) * 0.3162162162;
      c += (Texel(tex, tc + o2) + Texel(tex, tc - o2)) * 0.0702702703;
      return c * color;
    }
  ]])
  local spread = 1
  return moonshine.Effect({
    name = "blur",
    setters = { spread = function(v) spread = v end },
    defaults = { spread = 1 },
    draw = function(buffer)
      shader:send("spread", spread)
      shader:send("direction", { 1 / R.W, 0 })
      moonshine.draw_shader(buffer, shader)
      shader:send("direction", { 0, 1 / R.H })
      moonshine.draw_shader(buffer, shader)
    end,
  })
end

local function solidImage(r, g, b, a)
  local d = love.image.newImageData(1, 1)
  d:setPixel(0, 0, r, g, b, a or 1)
  local img = love.graphics.newImage(d)
  img:setFilter("nearest", "nearest")
  return img
end

function R.init()
  love.graphics.setDefaultFilter("nearest", "nearest")
  R.albedo = love.graphics.newCanvas(R.W, R.H)
  R.normal = love.graphics.newCanvas(R.W, R.H)
  R.emit = love.graphics.newCanvas(R.W, R.H)
  R.height = love.graphics.newCanvas(R.W, R.H)
  R.lit = love.graphics.newCanvas(R.W, R.H)
  R.final = love.graphics.newCanvas(R.W, R.H)
  R.ui = love.graphics.newCanvas(R.UIW, R.UIH)
  R.gshader = love.graphics.newShader(GBUFFER_SRC)
  R.lshader = love.graphics.newShader(LIGHT_SRC)
  R.flatN = solidImage(0.5, 0.5, 1.0)
  R.black = solidImage(0, 0, 0)
  R.white = solidImage(1, 1, 1)
  R.lshader:send("u_size", { R.W, R.H })

  R.post = moonshine(R.W, R.H, moonshine.effects.glow)
      .chain(moonshine.effects.desaturate)
      .chain(blurEffect())
      .chain(moonshine.effects.chromasep)
      .chain(moonshine.effects.vignette)
      .chain(moonshine.effects.filmgrain)
  R.post.glow.min_luma = 0.55
  R.post.glow.strength = 4
  R.post.desaturate.strength = 0
  R.post.desaturate.tint = { 255, 255, 255 }
  R.post.chromasep.radius = 0.6
  R.post.chromasep.angle = 0.3
  R.post.vignette.radius = 0.85
  R.post.vignette.softness = 0.55
  R.post.vignette.opacity = 0.75
  R.post.vignette.color = { 4, 3, 8 }
  R.post.filmgrain.opacity = 0.14
  R.post.filmgrain.size = 1
  R.post.disable("blur", "desaturate")
  R.fx = { blur = 0, desat = 0, grain = 0.14, vignette = 0.75, chroma = 0.6 }
  R.lastFx = {}
  R.saturation = 0.85
  R.exposure = 2.6
  R.tint = { 1, 1, 1 }
  R.resize(love.graphics.getDimensions())
end

-- ----------------------------------------------------------------------------
-- world pass
-- ----------------------------------------------------------------------------
function R.beginWorld(camx, camy)
  love.graphics.setCanvas(R.albedo, R.normal, R.emit, R.height)
  love.graphics.clear({ 0, 0, 0, 1 }, { 0.5, 0.5, 1, 1 }, { 0, 0, 0, 1 }, { 0, 0, 0, 1 })
  love.graphics.setShader(R.gshader)
  love.graphics.setBlendMode("alpha")
  love.graphics.push()
  love.graphics.translate(-camx, -camy)
  R.camx, R.camy = camx, camy
  R.gshader:send("u_mode", 0)
  R.gshader:send("u_flipX", 0)
  R.gshader:send("u_baseH", 0)
  R.gshader:send("u_emitScale", 1)
  R.mode, R.flip, R.baseH, R.emitScale = 0, 0, 0, 1
end

local function setMode(m)
  if R.mode ~= m then R.gshader:send("u_mode", m); R.mode = m end
end

local function setUniform(key, field, v)
  if R[field] ~= v then R.gshader:send(key, v); R[field] = v end
end

-- spr: table from assets.sprite(); opts: quad, sx, emit, baseH, color
function R.drawSprite(spr, x, y, opts)
  opts = opts or {}
  setMode(0)
  R.gshader:send("u_normal", spr.normal or R.flatN)
  R.gshader:send("u_height", spr.height or R.black)
  R.gshader:send("u_emit", spr.emit or R.black)
  local flip = (opts.sx and opts.sx < 0) and 1 or 0
  setUniform("u_flipX", "flip", flip)
  setUniform("u_baseH", "baseH", opts.baseH or 0)
  setUniform("u_emitScale", "emitScale", opts.emit or 1)
  if opts.color then love.graphics.setColor(opts.color) else love.graphics.setColor(1, 1, 1, 1) end
  local ox = (flip == 1) and (opts.quadW or spr.w) or 0
  if opts.quad then
    love.graphics.draw(spr.image, opts.quad, math.floor(x + 0.5), math.floor(y + 0.5), 0, opts.sx or 1, 1, ox, 0)
  else
    love.graphics.draw(spr.image, math.floor(x + 0.5), math.floor(y + 0.5), 0, opts.sx or 1, 1, ox, 0)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- flat-coloured primitives (lines, rects) that still take part in lighting
function R.flat(normal, height, emit)
  setMode(1)
  R.gshader:send("u_flatN", normal or { 0, 0, 1 })
  R.gshader:send("u_flatH", height or 0)
  R.gshader:send("u_flatE", emit or { 0, 0, 0 })
  setUniform("u_baseH", "baseH", 0)
end

-- albedo-only darkening (contact shadows)
function R.decal()
  setMode(2)
end

function R.endWorld()
  love.graphics.pop()
  love.graphics.setShader()
  love.graphics.setCanvas()
  love.graphics.setColor(1, 1, 1, 1)
end

-- ----------------------------------------------------------------------------
-- light pass
-- ----------------------------------------------------------------------------
-- lights: list of {x,y,z,r, color={r,g,b}, intensity, spot={dx,dy,cos}, shadows, halo}
-- (world coordinates; converted using the camera of beginWorld)
function R.light(lights, ambient)
  local pos, col, dir, misc = {}, {}, {}, {}
  local n = 0
  local cx, cy = R.camx or 0, R.camy or 0
  for li, l in ipairs(lights) do
    if n >= R.MAXL then break end
    if R.onlyLight and li ~= R.onlyLight then goto continue end
    local sx, sy = l.x - cx, l.y - cy
    local rr = l.r
    if l.intensity > 0.001 and sx + rr > 0 and sx - rr < R.W and sy - l.z + rr > 0 and sy - rr < R.H + 40 then
      n = n + 1
      local c = l.color
      pos[n] = { sx, sy, l.z, rr }
      col[n] = { c[1] * l.intensity, c[2] * l.intensity, c[3] * l.intensity, 1 }
      if l.spot then
        dir[n] = { l.spot[1], l.spot[2], l.spot[3], 1 }
      else
        dir[n] = { 0, 1, 0, 0 }
      end
      misc[n] = { (l.shadows == false or R.debugView == "noshadow") and 0 or 1, l.halo or 0, l.clear or 9, 0 }
    end
    ::continue::
  end
  for i = n + 1, 1 do -- shader arrays need at least one element sent
    pos[i], col[i], dir[i], misc[i] = { 0, 0, 0, 1 }, { 0, 0, 0, 0 }, { 0, 1, 0, 0 }, { 0, 0, 0, 0 }
  end
  if R.debugPrint then
    R.debugPrint = false
    for i = 1, n do print('light', i, unpack(pos[i])) print('  col', unpack(col[i])) end
  end
  local s = R.lshader
  s:send("u_count", n)
  s:send("u_lpos", unpack(pos))
  s:send("u_lcol", unpack(col))
  s:send("u_ldir", unpack(dir))
  s:send("u_lmisc", unpack(misc))
  s:send("u_ambient", ambient or { 0.05, 0.05, 0.07 })
  s:send("u_normal", R.normal)
  s:send("u_height", R.height)
  s:send("u_emit", R.emit)
  s:send("u_saturation", R.saturation)
  s:send("u_tint", R.tint)
  s:send("u_exposure", R.exposure)
  love.graphics.setCanvas(R.lit)
  love.graphics.clear(0, 0, 0, 1)
  local dv = R.debugView
  if dv and dv ~= "noshadow" then
    love.graphics.draw(({ albedo = R.albedo, normal = R.normal, height = R.height, emit = R.emit })[dv])
  else
    love.graphics.setShader(s)
    love.graphics.draw(R.albedo)
  end
  love.graphics.setShader()
  love.graphics.setCanvas()
  R.lightCount = n
end

-- ----------------------------------------------------------------------------
-- post + present
-- ----------------------------------------------------------------------------
local function syncFx()
  local fx, last, p = R.fx, R.lastFx, R.post
  if fx.blur ~= last.blur then
    if fx.blur > 0.05 then
      p.enable("blur"); p.blur.spread = fx.blur
    else
      p.disable("blur")
    end
    last.blur = fx.blur
  end
  if fx.desat ~= last.desat then
    if fx.desat > 0.01 then
      p.enable("desaturate"); p.desaturate.strength = fx.desat
    else
      p.disable("desaturate")
    end
    last.desat = fx.desat
  end
  if fx.grain ~= last.grain then p.filmgrain.opacity = fx.grain; last.grain = fx.grain end
  if fx.vignette ~= last.vignette then p.vignette.opacity = fx.vignette; last.vignette = fx.vignette end
  if fx.chroma ~= last.chroma then p.chromasep.radius = fx.chroma; last.chroma = fx.chroma end
end

-- overlay(fn) draws on top of the lit image before post (e.g. fog, particles)
function R.postProcess(overlay)
  syncFx()
  love.graphics.setCanvas(R.final)
  love.graphics.clear(0, 0, 0, 1)
  R.post(function()
    love.graphics.draw(R.lit)
    if overlay then overlay() end
  end)
  love.graphics.setCanvas()
end

-- draw directly on the final low-res image after post (fades, eyelids...)
function R.beginFinal()
  love.graphics.setCanvas(R.final)
end

function R.endFinal()
  love.graphics.setCanvas()
end

function R.beginUI()
  love.graphics.setCanvas(R.ui)
  love.graphics.clear(0, 0, 0, 0)
end

function R.endUI()
  love.graphics.setCanvas()
end

function R.resize(w, h)
  R.winW, R.winH = w, h
  local s = math.min(w / R.W, h / R.H)
  R.scale = s
  R.offX = math.floor((w - R.W * s) / 2)
  R.offY = math.floor((h - R.H * s) / 2)
  local up = math.max(1, math.ceil(s - 0.001))
  if up ~= R.upScale then
    R.upScale = up
    R.upCanvas = love.graphics.newCanvas(R.W * up, R.H * up)
    R.upCanvas:setFilter("linear", "linear")
  end
  local uiUp = math.max(1, math.ceil(s / 2 - 0.001))
  if uiUp ~= R.uiUpScale then
    R.uiUpScale = uiUp
    R.uiUpCanvas = love.graphics.newCanvas(R.UIW * uiUp, R.UIH * uiUp)
    R.uiUpCanvas:setFilter("linear", "linear")
  end
end

-- window coordinates -> internal coordinates
function R.toInternal(x, y)
  return (x - R.offX) / R.scale, (y - R.offY) / R.scale
end

function R.present()
  love.graphics.setCanvas(R.upCanvas)
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.draw(R.final, 0, 0, 0, R.upScale, R.upScale)
  love.graphics.setCanvas(R.uiUpCanvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.draw(R.ui, 0, 0, 0, R.uiUpScale, R.uiUpScale)
  love.graphics.setBlendMode("alpha")
  love.graphics.setCanvas()
  love.graphics.clear(0, 0, 0, 1)
  local k = R.scale / R.upScale
  love.graphics.draw(R.upCanvas, R.offX, R.offY, 0, k, k)
  local ku = R.scale / 2 / R.uiUpScale
  love.graphics.setBlendMode("alpha", "premultiplied")
  love.graphics.draw(R.uiUpCanvas, R.offX, R.offY, 0, ku, ku)
  love.graphics.setBlendMode("alpha")
end

return R
