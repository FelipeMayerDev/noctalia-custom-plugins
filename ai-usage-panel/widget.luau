--!nonstrict

local PROVIDERS = {
  { id = "claude", label = "Claude" },
  { id = "codex", label = "Codex" },
  { id = "copilot", label = "Copilot" },
  { id = "zen", label = "OpenCode Zen" },
  { id = "zai", label = "Z.ai" },
}

local providerData = noctalia.state.get("usage_providers") or {}

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

local function cleanText(value)
  local clean = tostring(value or ""):gsub("<[^>]+>", "")
  return noctalia.string.trim(clean)
end

local function compact(provider)
  local current = providerData[provider.id]
  if type(current) ~= "table" then
    return provider.label .. " …"
  end
  if current.error == true or current.class == "critical" then
    return provider.label .. " !"
  end
  local text = cleanText(current.text)
  if text == "" then
    return provider.label .. " ?"
  end
  if noctalia.getConfig("show_reset_time") == false then
    local short = text:match("^(%S+%s+%S+)")
    if short ~= nil then
      text = short
    end
  end
  return text
end

local function tooltip()
  local lines = {}
  local enabled = enabledSet()
  for _, provider in ipairs(PROVIDERS) do
    if enabled[provider.id] then
      local current = providerData[provider.id]
      local detail = "Loading…"
      if type(current) == "table" then
        detail = cleanText(current.tooltip or current.raw or current.text)
        if detail == "" then
          detail = current.error and "Unable to fetch usage" or "No usage data"
        end
      end
      table.insert(lines, provider.label .. ": " .. detail)
    end
  end
  return table.concat(lines, "\n")
end

local function render()
  local enabled = enabledSet()
  local labels = {}
  for _, provider in ipairs(PROVIDERS) do
    if enabled[provider.id] then
      table.insert(labels, compact(provider))
    end
  end
  barWidget.setGlyph("chart-bar")
  barWidget.setText(noctalia.getConfig("icon_only") == true and "" or table.concat(labels, " · "))
  barWidget.setTooltip(tooltip())
  barWidget.setVisible(#labels > 0)
end

function update()
  providerData = noctalia.state.get("usage_providers") or {}
  render()
end

function onClick()
  noctalia.togglePanel("felipemayerdev/ai-usage-panel:usage-panel")
end

function onRightClick()
  noctalia.openSettings()
end

noctalia.state.watch("usage_providers", function(value)
  providerData = type(value) == "table" and value or {}
  render()
end)

render()
