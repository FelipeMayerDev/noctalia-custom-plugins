--!nonstrict

local state = noctalia.state.get("hermes_state") or {}

local function currentStatus()
  local bridge = state.bridge or {}
  local hermes = state.hermes or {}
  if bridge.status ~= "online" then
    return "offline"
  end
  if hermes.status ~= nil and hermes.status ~= "unknown" then
    return hermes.status
  end
  local gateway = ((state.summary or {}).gateway or {}).status
  return gateway == "running" and "idle" or "unknown"
end

local function label(value)
  local keys = {
    offline = "status.offline",
    idle = "status.idle",
    busy = "status.busy",
    attention = "status.attention",
    degraded = "status.degraded",
    error = "status.error",
    unknown = "status.unknown",
  }
  return noctalia.tr(keys[value] or keys.unknown)
end

local function glyph(value)
  local values = {
    offline = "power",
    idle = "circle-check",
    busy = "loader",
    attention = "bell-ringing",
    degraded = "alert-circle",
    error = "alert-triangle",
    unknown = "sparkles",
  }
  return values[value] or "sparkles"
end

local function render()
  local value = currentStatus()
  local session = state.session or {}
  local hermes = state.hermes or {}
  local bridge = state.bridge or {}
  local hide = noctalia.getConfig("hide_when_idle") == true and value == "idle"
  local text = ""
  if not barWidget.isVertical() and value ~= "idle" and value ~= "unknown" then
    text = value == "attention" and "!" or label(value)
  end
  local tooltip = "Hermes: " .. label(value)
  if hermes.model ~= nil and hermes.model ~= "" then
    tooltip ..= " · " .. tostring(hermes.model)
  end
  if bridge.error ~= nil and bridge.error ~= "" then
    tooltip ..= "\n" .. tostring(bridge.error)
  end
  barWidget.setGlyph(glyph(value))
  barWidget.setText(text)
  barWidget.setTooltip(tooltip)
  barWidget.setVisible(not hide)
  if value == "offline" or value == "error" then
    barWidget.setGlyphColor("error")
  elseif value == "attention" then
    barWidget.setGlyphColor("tertiary")
  else
    barWidget.setGlyphColor("primary")
  end
end

function update()
  state = noctalia.state.get("hermes_state") or {}
  render()
end

function onClick()
  noctalia.togglePanel("felipemayerdev/hermes-agent:chat-panel")
end

function onRightClick()
  noctalia.openSettings()
end

noctalia.state.watch("hermes_state", function(value)
  state = type(value) == "table" and value or {}
  render()
end)

render()
