--!nonstrict

local PROVIDERS = {
  { id = "claude", label = "Claude", color = "#DE7356" },
  { id = "codex", label = "Codex", color = "#74AA9C" },
  { id = "copilot", label = "Copilot", color = "#8b5cf6" },
  { id = "zen", label = "OpenCode Zen", color = "#DE7356" },
  { id = "zai", label = "Z.ai", color = "#126EF4" },
}

local providerData = noctalia.state.get("usage_providers") or {}
local refreshing = noctalia.state.get("usage_refreshing") == true
local render

local function enabledSet()
  local configured = noctalia.getConfig("enabled_providers")
  local enabled = {}
  if type(configured) == "table" then
    for _, id in ipairs(configured) do
      enabled[id] = true
    end
  end
  return enabled
end

local function clean(value)
  return noctalia.string.trim(tostring(value or ""):gsub("<[^>]+>", ""))
end

local function percentage(value)
  if type(value) ~= "table" or value.error == true then
    return 0
  end
  return math.clamp(tonumber(value.percentage) or 0, 0, 100)
end

local function providerCard(provider)
  local value = providerData[provider.id]
  local pct = percentage(value)
  local summary = "Loading…"
  local details = ""
  if type(value) == "table" then
    summary = clean(value.text)
    details = clean(value.tooltip or value.raw)
    if value.error == true then
      summary = "Unable to fetch usage"
    elseif summary == "" then
      summary = "No usage data"
    end
  end
  if details == summary then
    details = ""
  end
  local children = {
    ui.row({ align = "center", gap = 8 }, {
      ui.label({ text = provider.label, fontWeight = "bold", color = provider.color, flexGrow = 1 }),
      ui.label({ text = string.format("%.0f%%", pct), color = "on_surface_variant" }),
    }),
    ui.progress({ progress = pct / 100, fill = pct >= 90 and "error" or provider.color, height = 7 }),
    ui.label({ text = summary, maxLines = 3 }),
  }
  if details ~= "" then
    table.insert(children, ui.label({ text = details, color = "on_surface_variant", maxLines = 8 }))
  end
  return ui.column({ key = provider.id, gap = 8, padding = 12, fill = "surface_variant/0.45", radius = 10 }, children)
end

render = function()
  local cards = {}
  local enabled = enabledSet()
  for _, provider in ipairs(PROVIDERS) do
    if enabled[provider.id] then
      table.insert(cards, providerCard(provider))
    end
  end
  if #cards == 0 then
    table.insert(cards, ui.label({ text = noctalia.tr("panel.no_providers"), color = "on_surface_variant" }))
  end
  panel.render(ui.column({ flexGrow = 1, gap = 14 }, {
    ui.row({ align = "center", gap = 8 }, {
      ui.glyph({ name = "chart-bar", size = 22, color = "primary" }),
      ui.label({ text = noctalia.tr("panel.title"), fontSize = 18, fontWeight = "bold", flexGrow = 1 }),
      ui.button({ text = refreshing and noctalia.tr("panel.refreshing") or noctalia.tr("panel.refresh"), glyph = "refresh", enabled = not refreshing, onClick = "onRefresh" }),
      ui.button({ glyph = "close", variant = "ghost", tooltip = noctalia.tr("panel.close"), onClick = "onCloseClicked" }),
    }),
    ui.scroll({ flexGrow = 1, gap = 10 }, cards),
  }))
end

function onOpen()
  render()
  if noctalia.getConfig("refresh_on_open") ~= false then
    local last = tonumber(noctalia.state.get("usage_last_refresh")) or 0
    if os.time() - last >= 10 then
      onRefresh()
    end
  end
end

function onRefresh()
  local request = tonumber(noctalia.state.get("usage_refresh_request")) or 0
  noctalia.state.set("usage_refresh_request", request + 1)
end

function onCloseClicked()
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
