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
local codexResetInFlight = noctalia.state.get("codex_reset_in_flight") == true
local codexResetError = tostring(noctalia.state.get("codex_reset_error") or "")
local confirmingCodexReset = false

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

local function formatRemaining(value)
  local resetAt = tonumber(value)
  if resetAt == nil then
    return ""
  end
  local totalMinutes = math.max(0, math.ceil((resetAt - os.time()) / 60))
  if totalMinutes <= 0 then
    return tr("panel.now")
  end
  if totalMinutes >= 24 * 60 then
    local days = math.floor(totalMinutes / (24 * 60))
    local hours = math.floor((totalMinutes % (24 * 60)) / 60)
    return string.format(tr("panel.remaining_days_hours"), days, hours)
  end
  local hours = math.floor(totalMinutes / 60)
  local minutes = totalMinutes % 60
  if hours > 0 then
    return string.format(tr("panel.remaining_hours_minutes"), hours, minutes)
  end
  return string.format(tr("panel.remaining_minutes"), minutes)
end

local function periodLabel(item)
  local seconds = tonumber(item.period_seconds)
  if seconds ~= nil and seconds > 0 then
    if seconds % (24 * 60 * 60) == 0 then
      local days = math.floor(seconds / (24 * 60 * 60))
      return string.format(tr(days == 1 and "period.day" or "period.days"), days)
    end
    if seconds % (60 * 60) == 0 then
      local hours = math.floor(seconds / (60 * 60))
      return string.format(tr(hours == 1 and "period.hour" or "period.hours"), hours)
    end
    local minutes = math.max(1, math.floor(seconds / 60))
    return string.format(tr(minutes == 1 and "period.minute" or "period.minutes"), minutes)
  end
  local key = tostring(item.period_key or "")
  if key == "monthly" then
    return tr("period.monthly")
  elseif key == "tools" then
    return tr("period.tools")
  end
  return tostring(item.label or tr("period.quota"))
end

local function quotaWindowNode(item, index)
  local percentage = math.clamp(tonumber(item.percentage) or 0, 0, 100)
  local children = {
    ui.label({ text = periodLabel(item), fontSize = 11, maxWidth = 64 }),
    ui.progress({ progress = percentage / 100, width = 108, height = 5, radius = 3 }),
    ui.label({ text = string.format("%.0f%%", percentage), fontSize = 11, fontWeight = "bold", maxWidth = 36 }),
  }
  local reset = formatRemaining(item.resets_at)
  if noctalia.getConfig("show_reset_time") ~= false and reset ~= "" then
    table.insert(children, ui.spacer({ flexGrow = 1 }))
    table.insert(children, ui.label({
      text = reset,
      fontSize = 10,
      color = "on_surface_variant",
      maxLines = 1,
    }))
  end
  return ui.row({ key = `window={index}`, gap = 6, align = "center" }, children)
end
local function appendCodexResetControls(content, data)
  local resetCredits = type(data) == "table" and data.reset_credits or nil
  if type(resetCredits) ~= "table" then
    return
  end
  local available = math.max(0, tonumber(resetCredits.available_count) or 0)
  local applicable = math.max(0, tonumber(resetCredits.applicable_available_count) or 0)
  table.insert(content, ui.row({ gap = 6, align = "center" }, {
    ui.label({
      text = string.format(tr("panel.codex_resets"), available, applicable),
      fontSize = 10,
      color = "on_surface_variant",
    }),
    ui.spacer({ flexGrow = 1 }),
    ui.button({
      text = codexResetInFlight and tr("panel.resetting") or tr("panel.reset_now"),
      variant = "outline",
      controlSize = "sm",
      fontSize = 9,
      height = 20,
      enabled = applicable > 0 and data.stale ~= true and not codexResetInFlight,
      onClick = "onRequestCodexReset",
    }),
  }))
  if confirmingCodexReset then
    table.insert(content, ui.column({
      gap = 5,
      padding = 7,
      radius = 6,
      border = "error",
      borderWidth = 1,
    }, {
      ui.label({
        text = tr("panel.reset_confirmation"),
        fontSize = 10,
        color = "error",
        maxLines = 2,
      }),
      ui.row({ gap = 6, align = "center" }, {
        ui.spacer({ flexGrow = 1 }),
        ui.button({ text = tr("panel.cancel"), variant = "ghost", controlSize = "sm", onClick = "onCancelCodexReset" }),
        ui.button({ text = tr("panel.confirm_reset"), variant = "destructive", controlSize = "sm", onClick = "onConfirmCodexReset" }),
      }),
    }))
  end
  if codexResetError ~= "" then
    table.insert(content, ui.label({ text = codexResetError, fontSize = 10, color = "error", maxLines = 2 }))
  end
end


local function providerCard(provider, data)
  local headerValue = "…"
  if type(data) == "table" then
    headerValue = tostring(data.summary or "—")
  end
  local header = {
    ui.glyph({ name = provider.glyph, size = 16, color = provider.color }),
    ui.label({ text = provider.label, fontSize = 13, fontWeight = "bold" }),
  }
  if type(data) == "table" and type(data.details) == "string" and data.details ~= "" and data.details:find("\n", 1, true) == nil and #data.details <= 40 then
    table.insert(header, ui.label({ text = "· " .. data.details, fontSize = 10, color = "on_surface_variant" }))
  end
  table.insert(header, ui.spacer({ flexGrow = 1 }))
  table.insert(header, ui.label({ text = headerValue, fontSize = 13, fontWeight = "bold", color = provider.color }))

  local content = {
    ui.row({ gap = 6, align = "center" }, header),
  }
  if type(data) ~= "table" then
    table.insert(content, ui.label({ text = tr("panel.waiting"), fontSize = 10, color = "on_surface_variant" }))
  elseif data.status ~= "ok" and data.stale ~= true then
    table.insert(content, ui.label({
      text = tostring(data.error or tr("panel.unavailable")),
      fontSize = 10,
      color = "error",
      maxLines = 2,
    }))
  else
    for index, item in ipairs(data.windows or {}) do
      table.insert(content, quotaWindowNode(item, index))
    end
    if provider.id == "codex" then
      appendCodexResetControls(content, data)
    end
    if data.stale == true then
      table.insert(content, ui.label({
        text = tr("panel.stale") .. ": " .. tostring(data.error or ""),
        fontSize = 10,
        color = "primary",
        maxLines = 2,
      }))
    end
  end

  return ui.column({
    key = "provider=" .. provider.id,
    paddingH = 10,
    paddingV = 7,
    gap = 5,
    fill = "surface_variant/0.45",
    radius = 8,
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
      padding = 12,
      fill = "surface_variant/0.45",
      radius = 8,
    }, {
      ui.label({ text = tr("panel.no_providers"), fontSize = 11, textAlign = "center", maxLines = 2 }),
    }))
  end

  local status = refreshing and tr("panel.refreshing") or tr("panel.refresh")
  if not refreshing and lastRefresh ~= nil then
    status = tr("panel.updated") .. " " .. noctalia.formatTime("%H:%M", lastRefresh)
  end

  panel.render(ui.column({ gap = 8, padding = 12 }, {
    ui.row({ align = "center", gap = 6 }, {
      ui.glyph({ name = "chart-bar", size = 20, color = "primary" }),
      ui.label({ text = tr("panel.title"), fontSize = 14, fontWeight = "bold" }),
      ui.spacer({ flexGrow = 1 }),
      ui.button({
        text = status,
        glyph = "refresh",
        variant = "ghost",
        controlSize = "sm",
        enabled = not refreshing,
        onClick = "onRefresh",
      }),
      ui.button({ glyph = "x", variant = "ghost", controlSize = "sm", onClick = "onClose" }),
    }),
    ui.scroll({ flexGrow = 1, gap = 6 }, cards),
  }))
end

function onRefresh()
  refresh()
end

function onClose()
  confirmingCodexReset = false
  panel.close()
end

function onRequestCodexReset()
  local codexData = providerData.codex
  local resetCredits = type(codexData) == "table" and codexData.reset_credits or nil
  if type(resetCredits) ~= "table" or codexData.stale == true or (tonumber(resetCredits.applicable_available_count) or 0) <= 0 then
    return
  end
  confirmingCodexReset = true
  render()
end

function onCancelCodexReset()
  confirmingCodexReset = false
  render()
end

function onConfirmCodexReset()
  if not confirmingCodexReset then
    return
  end
  local codexData = providerData.codex
  local resetCredits = type(codexData) == "table" and codexData.reset_credits or nil
  if type(resetCredits) ~= "table" or codexData.stale == true or (tonumber(resetCredits.applicable_available_count) or 0) <= 0 then
    confirmingCodexReset = false
    render()
    return
  end
  confirmingCodexReset = false
  local nonce = (tonumber(noctalia.state.get("codex_reset_request")) or 0) + 1
  noctalia.state.set("codex_reset_request", nonce)
  render()
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

noctalia.state.watch("codex_reset_in_flight", function(value)
  codexResetInFlight = value == true
  render()
end)

noctalia.state.watch("codex_reset_error", function(value)
  codexResetError = tostring(value or "")
  render()
end)

function onConfigChanged()
  render()
end

function update()
  render()
end

noctalia.setUpdateInterval(60000)
render()
