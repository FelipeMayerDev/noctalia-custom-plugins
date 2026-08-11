--!nonstrict

local PROVIDERS = {
  { id = "claude", command = "claude-usage --json" },
  { id = "codex", command = "codex-usage --json" },
  { id = "copilot", command = "copilot-usage --json" },
  { id = "zen", command = "zen-balance --json" },
  { id = "zai", command = "zai-usage --json" },
}

local data = noctalia.state.get("usage_providers") or {}
local refreshing = false
local pending = 0

local function configuredProviders()
  local configured = noctalia.getConfig("enabled_providers")
  local enabled = {}
  if type(configured) == "table" then
    for _, id in ipairs(configured) do
      enabled[id] = true
    end
  end
  return enabled
end

local function publish()
  noctalia.state.set("usage_providers", data)
  noctalia.state.set("usage_refreshing", refreshing)
end

local function finishProvider(id, result)
  local parsed = nil
  if result.exitCode == 0 then
    parsed = noctalia.json.decode(noctalia.string.trim(result.stdout or ""))
  end
  if type(parsed) ~= "table" then
    parsed = {
      error = true,
      raw = noctalia.string.trim(result.stderr or result.stdout or ""),
    }
    if parsed.raw == "" then
      parsed.raw = `Command failed with exit code {result.exitCode}`
    end
  end
  data[id] = parsed
  pending -= 1
  if pending <= 0 then
    pending = 0
    refreshing = false
    noctalia.state.set("usage_last_refresh", os.time())
  end
  publish()
end

local function syncZaiToken()
  local token = noctalia.getConfig("zai_token")
  if type(token) ~= "string" or token == "" then
    return
  end
  local dir = "~/.config/plasma-ai-usage-panel"
  local ok, err = noctalia.mkdirAll(dir)
  if not ok then
    noctalia.log(`ai-usage-panel: unable to create token directory: {err or "unknown error"}`)
    return
  end
  ok, err = noctalia.writeFile(dir .. "/zai.conf", "ZAI_TOKEN=" .. token .. "\n")
  if not ok then
    noctalia.log(`ai-usage-panel: unable to write Z.ai token: {err or "unknown error"}`)
    return
  end
  noctalia.runAsync("chmod 600 \"$HOME/.config/plasma-ai-usage-panel/zai.conf\"")
end

local function refreshAll()
  if refreshing then
    return
  end
  local enabled = configuredProviders()
  pending = 0
  for _, provider in ipairs(PROVIDERS) do
    if enabled[provider.id] then
      pending += 1
    end
  end
  refreshing = pending > 0
  publish()
  if pending == 0 then
    return
  end
  for _, provider in ipairs(PROVIDERS) do
    if enabled[provider.id] then
      local command = "export PATH=\"$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin:$PATH\"; " .. provider.command
      local accepted = noctalia.runAsync(command, function(result)
        finishProvider(provider.id, result)
      end, 60000)
      if not accepted then
        finishProvider(provider.id, {
          exitCode = -1,
          stdout = "",
          stderr = "Unable to start command",
        })
      end
    end
  end
end

local function configureInterval()
  local seconds = tonumber(noctalia.getConfig("refresh_interval_seconds")) or 120
  noctalia.setUpdateInterval(math.max(30, seconds) * 1000)
end

function update()
  refreshAll()
end

function onConfigChanged()
  configureInterval()
  syncZaiToken()
  refreshAll()
end

noctalia.state.watch("usage_refresh_request", function()
  refreshAll()
end)

configureInterval()
syncZaiToken()
refreshAll()
