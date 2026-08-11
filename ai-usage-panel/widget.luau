--!nonstrict

local PROVIDERS = {
  { id = "claude", label = "Claude", icon = "assets/claude.svg", color = "#D97757" },
  { id = "codex", label = "Codex", icon = "assets/codex.svg", color = "#74A9C9" },
  { id = "copilot", label = "Copilot", glyph = "brand-github", color = "#8B5CF6" },
  { id = "zen", label = "Zen", glyph = "coins", color = "#DE7356" },
  { id = "zai", label = "Z.ai", icon = "assets/zai.svg", color = "#126EF4" },
}

local providerData = noctalia.state.get("usage_providers") or {}
local refreshing = noctalia.state.get("usage_refreshing") == true

local function configuredIds()
  local configured = noctalia.getConfig("enabled_providers")
  return type(configured) == "table" and configured or {}
end

local function providerFor(id)
  for _, provider in ipairs(PROVIDERS) do
    if provider.id == id then
      return provider
    end
  end
  return nil
end

local function statusText(data)
  if type(data) ~= "table" then
    return "…"
  end
  if data.status ~= "ok" and data.stale ~= true then
    return "!"
  end
  local value = data.summary or "—"
  return data.stale == true and "~" .. tostring(value) or tostring(value)
end
local function percentageText(data)
  if type(data) ~= "table" then
    return "…"
  end
  if data.status ~= "ok" and data.stale ~= true then
    return "!"
  end
  local percentage = tonumber(data.percentage)
  if percentage == nil then
    return "—"
  end
  local value = string.format("%.0f%%", math.clamp(percentage, 0, 100))
  return data.stale == true and "~" .. value or value
end


local function tooltipText()
  local lines = { refreshing and "AI usage · Refreshing…" or "AI usage" }
  for _, id in ipairs(configuredIds()) do
    local provider = providerFor(id)
    local data = providerData[id]
    if provider ~= nil then
      if type(data) ~= "table" then
        table.insert(lines, provider.label .. ": Waiting for data")
      elseif data.status == "ok" or data.stale == true then
        local line = provider.label .. ": " .. tostring(data.summary or "—")
        if data.stale == true then
          line ..= " (stale)"
        end
        table.insert(lines, line)
        if data.error ~= nil and data.error ~= "" then
          table.insert(lines, "  " .. tostring(data.error))
        end
      else
        table.insert(lines, provider.label .. ": " .. tostring(data.error or "Unavailable"))
      end
    end
  end
  table.insert(lines, "Right-click to refresh")
  return table.concat(lines, "\n")
end
local function providerIconNode(provider, size)
  if provider.icon ~= nil then
    return ui.image({ path = provider.icon, width = size, height = size, fit = "contain" })
  end
  return ui.glyph({ name = provider.glyph, size = size, color = provider.color })
end


local function providerNode(provider, data, iconOnly, fontSize)
  if iconOnly then
    return ui.row({
      key = "provider=" .. provider.id,
      gap = 3,
      align = "center",
    }, {
      providerIconNode(provider, fontSize + 3),
      ui.label({
        text = percentageText(data),
        fontSize = fontSize,
        fontWeight = "semibold",
        color = (type(data) == "table" and data.status == "error") and "error" or "on_surface",
      }),
    })
  end
  return ui.row({
    key = "provider=" .. provider.id,
    gap = 4,
    align = "center",
  }, {
    ui.label({ text = provider.label, fontSize = fontSize, color = provider.color, fontWeight = "bold" }),
    ui.label({
      text = statusText(data),
      fontSize = fontSize,
      color = (type(data) == "table" and data.status == "error") and "error" or "on_surface",
    }),
  })
end

local function render()
  local children = {}
  local iconOnly = noctalia.getConfig("icon_only") == true
  local fontSize = math.clamp(tonumber(noctalia.getConfig("bar_font_size")) or 12, 8, 24)
  for _, id in ipairs(configuredIds()) do
    local provider = providerFor(id)
    if provider ~= nil then
      table.insert(children, providerNode(provider, providerData[id], iconOnly, fontSize))
    end
  end
  if refreshing then
    table.insert(children, ui.glyph({ key = "refreshing", name = "refresh", size = 12, color = "primary" }))
  end
  barWidget.setVisible(#children > 0)
  barWidget.setTooltip(tooltipText())
  local container = barWidget.isVertical() and ui.column or ui.row
  barWidget.render(container({ gap = 8, align = "center" }, children))
end

function onClick()
  noctalia.panel.toggle("usage-panel")
end

function onRightClick()
  local nonce = (tonumber(noctalia.state.get("usage_refresh_request")) or 0) + 1
  noctalia.state.set("usage_refresh_request", nonce)
end

function onIpc(event)
  if event == "refresh" then
    onRightClick()
  end
end

noctalia.state.watch("usage_providers", function(value)
  providerData = type(value) == "table" and value or {}
  render()
end)

noctalia.state.watch("usage_refreshing", function(value)
  refreshing = value == true
  render()
end)

function onConfigChanged()
  render()
end

render()
