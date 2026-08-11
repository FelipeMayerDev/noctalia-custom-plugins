--!nonstrict

local PROVIDERS = {
  { id = "claude", label = "Claude", glyph = "sparkles", color = "#DE7356" },
  { id = "codex", label = "Codex", glyph = "code", color = "#74A9C9" },
  { id = "copilot", label = "Copilot", glyph = "brand-github", color = "#8B5CF6" },
  { id = "zen", label = "OpenCode Zen", glyph = "coins", color = "#DE7356" },
  { id = "zai", label = "Z.ai", glyph = "brain", color = "#126EF4" },
}

local providerData = noctalia.state.get("usage_providers") or {}
local refreshing = noctalia.state.get("usage_refreshing") == true
local lastRefresh = tonumber(noctalia.state.get("usage_last_refresh"))

local function tr(key)
  return noctalia.tr(key)
end

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

local function refresh()
  local nonce = (tonumber(noctalia.state.get("usage_refresh_request")) or 0) + 1
  noctalia.state.set("usage_refresh_request", nonce)
end

local function formatReset(value)
  if value == nil or value == "" then
    return ""
  end
  if type(value) == "number" then
    local seconds = value > 100000000000 and math.floor(value / 1000) or math.floor(value)
    return noctalia.formatTime("%Y-%m-%d %H:%M", seconds)
  end
  return tostring(value):gsub("T", " "):gsub("%.000Z$", " UTC"):gsub("Z$", " UTC")
end

local function quotaWindowNode(item, index)
  local percentage = math.clamp(tonumber(item.percentage) or 0, 0, 100)
  local nodes = {
    ui.row({ gap = 8 }, {
      ui.label({ text = tostring(item.label or tr("panel.quota")) }),
      ui.spacer({ flexGrow = 1 }),
      ui.label({ text = string.format("%.0f%%", percentage), fontWeight = "bold" }),
    }),
    ui.progress({ progress = percentage / 100 }),
  }
  local reset = formatReset(item.resets_at)
  if noctalia.getConfig("show_reset_time") ~= false and reset ~= "" then
    table.insert(nodes, ui.label({
      text = tr("panel.resets") .. " " .. reset,
      color = "on_surface_variant",
      maxLines = 2,
    }))
  end
  return ui.column({ key = `window={index}`, gap = 4 }, nodes)
end

local function providerCard(provider, data)
  local headerValue = "…"
  if type(data) == "table" then
    headerValue = tostring(data.summary or "—")
  end
  local content = {
    ui.row({ gap = 10, align = "center" }, {
      ui.glyph({ name = provider.glyph, size = 20, color = provider.color }),
      ui.label({ text = provider.label, fontWeight = "bold" }),
      ui.spacer({ flexGrow = 1 }),
      ui.label({ text = headerValue, fontWeight = "bold", color = provider.color }),
    }),
  }

  if type(data) ~= "table" then
    table.insert(content, ui.label({ text = tr("panel.waiting"), color = "on_surface_variant" }))
  elseif data.status ~= "ok" and data.stale ~= true then
    table.insert(content, ui.label({
      text = tostring(data.error or tr("panel.unavailable")),
      color = "error",
      maxLines = 4,
    }))
  else
    for index, item in ipairs(data.windows or {}) do
      table.insert(content, quotaWindowNode(item, index))
    end
    if type(data.details) == "string" and data.details ~= "" then
      table.insert(content, ui.label({ text = data.details, color = "on_surface_variant", maxLines = 3 }))
    end
    if data.stale == true then
      table.insert(content, ui.label({
        text = tr("panel.stale") .. ": " .. tostring(data.error or ""),
        color = "warning",
        maxLines = 4,
      }))
    end
  end

  if type(data) == "table" and type(data.source) == "string" and data.source ~= "" then
    table.insert(content, ui.label({ text = tr("panel.source") .. ": " .. data.source, color = "on_surface_variant" }))
  end

  return ui.column({
    key = "provider=" .. provider.id,
    padding = 14,
    gap = 10,
    fill = "surface_variant/0.55",
    radius = 12,
    border = "outline",
    borderWidth = 1,
  }, content)
end

local function render()
  local cards = {}
  for _, id in ipairs(configuredIds()) do
    local provider = providerFor(id)
    if provider ~= nil then
      table.insert(cards, providerCard(provider, providerData[id]))
    end
  end
  if #cards == 0 then
    table.insert(cards, ui.column({
      padding = 20,
      fill = "surface_variant/0.55",
      radius = 12,
    }, {
      ui.label({ text = tr("panel.no_providers"), textAlign = "center", maxLines = 3 }),
    }))
  end

  local status = refreshing and tr("panel.refreshing") or tr("panel.refresh")
  if not refreshing and lastRefresh ~= nil then
    status = tr("panel.updated") .. " " .. noctalia.formatTime("%H:%M", lastRefresh)
  end

  panel.render(ui.column({ gap = 14, padding = 18 }, {
    ui.row({ align = "center", gap = 10 }, {
      ui.glyph({ name = "chart-bar", size = 24, color = "primary" }),
      ui.label({ text = tr("panel.title"), fontWeight = "bold" }),
      ui.spacer({ flexGrow = 1 }),
      ui.button({
        text = status,
        glyph = "refresh",
        variant = "ghost",
        enabled = not refreshing,
        onClick = "onRefresh",
      }),
      ui.button({ glyph = "x", variant = "ghost", onClick = "onClose" }),
    }),
    ui.scroll({ flexGrow = 1, gap = 10 }, cards),
  }))
end

function onRefresh()
  refresh()
end

function onClose()
  panel.close()
end

noctalia.state.watch("usage_providers", function(value)
  providerData = type(value) == "table" and value or {}
  render()
end)

noctalia.state.watch("usage_refreshing", function(value)
  refreshing = value == true
  render()
end)

noctalia.state.watch("usage_last_refresh", function(value)
  lastRefresh = tonumber(value)
  render()
end)

function onConfigChanged()
  render()
  if noctalia.getConfig("refresh_on_open") == true then
    refresh()
  end
end

render()
if noctalia.getConfig("refresh_on_open") == true then
  refresh()
end
