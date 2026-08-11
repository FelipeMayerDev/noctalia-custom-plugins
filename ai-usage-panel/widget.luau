--!nonstrict

local PROVIDERS = {
  { id = "claude", label = "Claude", short = "C", color = "#DE7356" },
  { id = "codex", label = "Codex", short = "CX", color = "#74A9C9" },
  { id = "copilot", label = "Copilot", short = "GH", color = "#8B5CF6" },
  { id = "zen", label = "Zen", short = "Z", color = "#DE7356" },
  { id = "zai", label = "Z.ai", short = "ZAI", color = "#126EF4" },
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

local function providerNode(provider, data, iconOnly)
  local value = statusText(data)
  if iconOnly then
    return ui.label({
      key = "provider=" .. provider.id,
      text = provider.short,
      color = provider.color,
      fontWeight = "bold",
    })
  end
  return ui.row({
    key = "provider=" .. provider.id,
    gap = 4,
    align = "center",
  }, {
    ui.label({ text = provider.label, color = provider.color, fontWeight = "bold" }),
    ui.label({ text = value, color = (type(data) == "table" and data.status == "error") and "error" or "on_surface" }),
  })
end

local function render()
  local children = {}
  local iconOnly = noctalia.getConfig("icon_only") == true
  for _, id in ipairs(configuredIds()) do
    local provider = providerFor(id)
    if provider ~= nil then
      table.insert(children, providerNode(provider, providerData[id], iconOnly))
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
