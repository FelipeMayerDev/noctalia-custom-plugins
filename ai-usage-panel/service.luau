--!nonstrict

local PROVIDERS = {
  { id = "claude", source = "Claude Code OAuth" },
  { id = "codex", source = "Codex CLI OAuth" },
  { id = "copilot", source = "GitHub CLI OAuth" },
  { id = "zen", source = "zen-balance helper" },
  { id = "zai", source = "Z.ai API" },
}

local providerData = noctalia.state.get("usage_providers") or {}
local refreshing = false
local pending = 0
local generation = 0

local function configuredProviderIds()
  local configured = noctalia.getConfig("enabled_providers")
  local result = {}
  if type(configured) == "table" then
    for _, id in ipairs(configured) do
      for _, provider in ipairs(PROVIDERS) do
        if id == provider.id then
          table.insert(result, id)
          break
        end
      end
    end
  end
  return result
end

local function sourceFor(id)
  for _, provider in ipairs(PROVIDERS) do
    if provider.id == id then
      return provider.source
    end
  end
  return "Unknown"
end

local function publish()
  noctalia.state.set("usage_providers", providerData)
  noctalia.state.set("usage_refreshing", refreshing)
end

local function copyTable(value)
  local result = {}
  for key, item in pairs(value or {}) do
    result[key] = item
  end
  return result
end

local function finish(requestGeneration, id, result, err)
  if requestGeneration ~= generation then
    return
  end
  if err ~= nil then
    local previous = providerData[id]
    if type(previous) == "table" and (previous.status == "ok" or previous.stale == true) then
      local stale = copyTable(previous)
      stale.stale = true
      stale.error = tostring(err)
      providerData[id] = stale
    else
      providerData[id] = {
        status = "error",
        source = sourceFor(id),
        summary = "Unavailable",
        windows = {},
        error = tostring(err),
        updated_at = os.time(),
      }
    end
  else
    result.status = "ok"
    result.source = result.source or sourceFor(id)
    result.stale = false
    result.error = ""
    result.updated_at = os.time()
    providerData[id] = result
  end
  pending -= 1
  if pending <= 0 then
    pending = 0
    refreshing = false
    noctalia.state.set("usage_last_refresh", os.time())
  end
  publish()
end

local function httpJson(request, onDone)
  local accepted = noctalia.http(request, function(response)
    if not response.ok then
      onDone(nil, "Network request failed")
      return
    end
    if response.status < 200 or response.status >= 300 then
      if response.status == 401 or response.status == 403 then
        onDone(nil, `Authentication failed (HTTP {response.status})`)
      else
        onDone(nil, `Provider returned HTTP {response.status}`)
      end
      return
    end
    local decoded, decodeError = noctalia.json.decode(response.body or "")
    if type(decoded) ~= "table" then
      onDone(nil, decodeError or "Invalid JSON response")
      return
    end
    onDone(decoded, nil)
  end)
  if not accepted then
    onDone(nil, "Unable to start network request")
  end
end

local function pct(value)
  return math.clamp(tonumber(value) or 0, 0, 100)
end

local function daysFromCivil(year, month, day)
  local adjustedYear = year - (month <= 2 and 1 or 0)
  local era = math.floor(adjustedYear / 400)
  local yearOfEra = adjustedYear - era * 400
  local adjustedMonth = month + (month > 2 and -3 or 9)
  local dayOfYear = math.floor((153 * adjustedMonth + 2) / 5) + day - 1
  local dayOfEra = yearOfEra * 365 + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100) + dayOfYear
  return era * 146097 + dayOfEra - 719468
end

local function timestampSeconds(value)
  local timestamp = tonumber(value)
  if timestamp ~= nil then
    return timestamp > 100000000000 and math.floor(timestamp / 1000) or math.floor(timestamp)
  end
  local raw = tostring(value or "")
  local year, month, day, hour, minute, second = raw:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)")
  if year == nil then
    return nil
  end
  local result = daysFromCivil(tonumber(year), tonumber(month), tonumber(day)) * 86400
    + tonumber(hour) * 3600 + tonumber(minute) * 60 + tonumber(second)
  local sign, offsetHour, offsetMinute = raw:match("([+-])(%d%d):(%d%d)$")
  if sign ~= nil then
    local offset = tonumber(offsetHour) * 3600 + tonumber(offsetMinute) * 60
    result += sign == "+" and -offset or offset
  end
  return result
end

local function window(periodSeconds, periodKey, percentage, resetsAt)
  return {
    period_seconds = tonumber(periodSeconds),
    period_key = periodKey,
    percentage = pct(percentage),
    resets_at = timestampSeconds(resetsAt),
  }
end

local function selectedPercentage(windows)
  local highest = 0
  for _, item in ipairs(windows) do
    highest = math.max(highest, tonumber(item.percentage) or 0)
  end
  return highest
end

local function normalizeWindowResult(windows, details)
  local percentage = selectedPercentage(windows)
  return {
    percentage = percentage,
    summary = string.format("%.0f%%", percentage),
    details = details or "",
    windows = windows,
  }
end

local function readJsonFile(path)
  local contents, readError = noctalia.readFile(path)
  if contents == nil then
    return nil, readError or `Unable to read {path}`
  end
  local decoded, decodeError = noctalia.json.decode(contents)
  if type(decoded) ~= "table" then
    return nil, decodeError or `Invalid JSON in {path}`
  end
  return decoded, nil
end

local function collectClaude(requestGeneration)
  local credentials, credentialsError = readJsonFile("~/.claude/.credentials.json")
  if credentials == nil then
    finish(requestGeneration, "claude", nil, "Claude Code is not signed in; run claude and authenticate")
    return
  end
  local oauth = credentials.claudeAiOauth
  local token = type(oauth) == "table" and oauth.accessToken or nil
  if type(token) ~= "string" or token == "" then
    finish(requestGeneration, "claude", nil, "Claude OAuth token not found; sign in again with Claude Code")
    return
  end
  local expiresAt = tonumber(oauth.expiresAt)
  if expiresAt ~= nil and expiresAt <= os.time() * 1000 then
    finish(requestGeneration, "claude", nil, "Claude OAuth token expired; open Claude Code to refresh it")
    return
  end
  httpJson({
    url = "https://api.anthropic.com/api/oauth/usage",
    headers = {
      "Authorization: Bearer " .. token,
      "anthropic-beta: oauth-2025-04-20",
      "Accept: application/json",
      "User-Agent: noctalia-ai-usage-panel/1.1",
    },
  }, function(payload, err)
    if payload == nil then
      finish(requestGeneration, "claude", nil, err)
      return
    end
    local fiveHour = payload.five_hour or {}
    local sevenDay = payload.seven_day or {}
    local windows = {
      window(5 * 60 * 60, nil, fiveHour.utilization, fiveHour.resets_at),
      window(7 * 24 * 60 * 60, nil, sevenDay.utilization, sevenDay.resets_at),
    }
    local plan = type(oauth.subscriptionType) == "string" and oauth.subscriptionType or ""
    finish(requestGeneration, "claude", normalizeWindowResult(windows, plan), nil)
  end)
end

local function codexHeaders()
  local credentials = readJsonFile("~/.codex/auth.json")
  if credentials == nil then
    return nil, "Codex CLI is not signed in; run codex login"
  end
  local tokens = credentials.tokens
  local accessToken = type(tokens) == "table" and tokens.access_token or nil
  local accountId = type(tokens) == "table" and tokens.account_id or nil
  if type(accessToken) ~= "string" or accessToken == "" then
    return nil, "Codex OAuth token not found; run codex login"
  end
  local headers = {
    "Authorization: Bearer " .. accessToken,
    "Accept: application/json",
    "User-Agent: noctalia-ai-usage-panel/1.4",
  }
  if type(accountId) == "string" and accountId ~= "" then
    table.insert(headers, "ChatGPT-Account-Id: " .. accountId)
  end
  return headers, nil
end

local function collectCodex(requestGeneration)
  local headers, authError = codexHeaders()
  if headers == nil then
    finish(requestGeneration, "codex", nil, authError)
    return
  end
  httpJson({
    url = "https://chatgpt.com/backend-api/wham/usage",
    headers = headers,
  }, function(payload, err)
    if payload == nil then
      finish(requestGeneration, "codex", nil, err)
      return
    end
    local limits = payload.rate_limit or {}
    local primary = limits.primary_window
    local secondary = limits.secondary_window
    local windows = {}
    if type(primary) == "table" and primary.used_percent ~= nil then
      table.insert(windows, window(primary.limit_window_seconds, "quota", primary.used_percent, primary.reset_at))
    end
    if type(secondary) == "table" and secondary.used_percent ~= nil then
      table.insert(windows, window(secondary.limit_window_seconds, "quota", secondary.used_percent, secondary.reset_at))
    end
    local details = tostring(payload.plan_type or "")
    if type(payload.credits) == "table" and payload.credits.balance ~= nil then
      details ..= details ~= "" and ` · {payload.credits.balance} credits` or `{payload.credits.balance} credits`
    end
    local result = normalizeWindowResult(windows, details)
    if type(payload.rate_limit_reset_credits) ~= "table" then
      finish(requestGeneration, "codex", result, nil)
      return
    end
    result.reset_credits = {
      available_count = math.max(0, tonumber(payload.rate_limit_reset_credits.available_count) or 0),
      applicable_available_count = math.max(0, tonumber(payload.rate_limit_reset_credits.applicable_available_count) or 0),
      credits = {},
    }
    httpJson({
      url = "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits",
      headers = headers,
    }, function(resetPayload, _resetError)
      if type(resetPayload) == "table" then
        if resetPayload.available_count ~= nil then
          result.reset_credits.available_count = math.max(0, tonumber(resetPayload.available_count) or 0)
        end
        for _, credit in ipairs(resetPayload.credits or {}) do
          if type(credit) == "table" and credit.status == "available" then
            table.insert(result.reset_credits.credits, {
              title = tostring(credit.title or ""),
              expires_at = timestampSeconds(credit.expires_at),
            })
          end
        end
      end
      finish(requestGeneration, "codex", result, nil)
    end)
  end)
end

local function collectCopilot(requestGeneration)
  if not noctalia.commandExists("gh") then
    finish(requestGeneration, "copilot", nil, "GitHub CLI not found; install gh and authenticate")
    return
  end
  local accepted = noctalia.runAsync("gh auth token", function(commandResult)
    local token = noctalia.string.trim(commandResult.stdout or "")
    if commandResult.exitCode ~= 0 or token == "" then
      finish(requestGeneration, "copilot", nil, "GitHub CLI is not authenticated; run gh auth login")
      return
    end
    local baseHeaders = {
      "Authorization: Bearer " .. token,
      "Accept: application/vnd.github+json",
      "X-GitHub-Api-Version: 2022-11-28",
      "User-Agent: noctalia-ai-usage-panel/1.1",
    }
    httpJson({ url = "https://api.github.com/user", headers = baseHeaders }, function(user, userError)
      local login = type(user) == "table" and user.login or nil
      if type(login) ~= "string" or login == "" then
        finish(requestGeneration, "copilot", nil, userError or "Unable to identify the GitHub account")
        return
      end
      httpJson({
        url = "https://api.github.com/users/" .. noctalia.string.urlEncode(login) .. "/settings/billing/premium_request/usage",
        headers = baseHeaders,
      }, function(payload, usageError)
        if payload == nil then
          finish(requestGeneration, "copilot", nil, usageError)
          return
        end
        local items = payload.usageItems or payload
        local used = 0
        if type(items) == "table" then
          for _, item in ipairs(items) do
            used += tonumber(item.grossQuantity) or 0
          end
        end
        local quota = math.max(1, tonumber(noctalia.getConfig("copilot_monthly_quota")) or 300)
        local percentage = math.clamp(used / quota * 100, 0, 100)
        finish(requestGeneration, "copilot", {
          percentage = percentage,
          summary = string.format("%.0f / %d", used, quota),
          details = login,
          windows = { window(nil, "monthly", percentage, nil) },
        }, nil)
      end)
    end)
  end, 10000)
  if not accepted then
    finish(requestGeneration, "copilot", nil, "Unable to query GitHub CLI credentials")
  end
end

local function collectZen(requestGeneration)
  if not noctalia.commandExists("zen-balance") then
    finish(requestGeneration, "zen", nil, "zen-balance is optional and is not installed")
    return
  end
  local accepted = noctalia.runAsync("zen-balance --json", function(commandResult)
    if commandResult.exitCode ~= 0 then
      finish(requestGeneration, "zen", nil, noctalia.string.trim(commandResult.stderr or "") ~= "" and noctalia.string.trim(commandResult.stderr) or "zen-balance failed")
      return
    end
    local payload, decodeError = noctalia.json.decode(commandResult.stdout or "")
    if type(payload) ~= "table" then
      finish(requestGeneration, "zen", nil, decodeError or "Invalid zen-balance response")
      return
    end
    local summary = noctalia.string.trim(tostring(payload.text or payload.alt or "" ):gsub("<[^>]+>", ""))
    local details = noctalia.string.trim(tostring(payload.tooltip or ""):gsub("<[^>]+>", ""))
    finish(requestGeneration, "zen", {
      percentage = tonumber(payload.percentage),
      summary = summary ~= "" and summary or "Available",
      details = details,
      windows = {},
    }, nil)
  end, 30000)
  if not accepted then
    finish(requestGeneration, "zen", nil, "Unable to start zen-balance")
  end
end

local function collectZai(requestGeneration)
  local token = noctalia.string.trim(tostring(noctalia.getConfig("zai_token") or ""))
  if token == "" then
    finish(requestGeneration, "zai", nil, "Add a Z.ai API key in plugin settings")
    return
  end
  httpJson({
    url = "https://api.z.ai/api/monitor/usage/quota/limit",
    headers = {
      "Authorization: Bearer " .. token,
      "Accept: application/json",
      "User-Agent: noctalia-ai-usage-panel/1.1",
    },
  }, function(payload, err)
    if payload == nil then
      finish(requestGeneration, "zai", nil, err)
      return
    end
    if payload.success ~= true then
      finish(requestGeneration, "zai", nil, tostring(payload.msg or "Z.ai API rejected the request"))
      return
    end
    local limits = ((payload.data or {}).limits or {})
    local windows = {}
    for _, item in ipairs(limits) do
      local periodSeconds = nil
      local periodKey = nil
      if (item.type == "CREDIT_LIMIT" or item.type == "TOKENS_LIMIT") and item.unit == 3 and item.number == 5 then
        periodSeconds = 5 * 60 * 60
      elseif (item.type == "CREDIT_LIMIT" or item.type == "TOKENS_LIMIT") and item.unit == 6 and item.number == 1 then
        periodSeconds = 7 * 24 * 60 * 60
      elseif item.type == "TIME_LIMIT" then
        periodKey = "tools"
      end
      if periodSeconds ~= nil or periodKey ~= nil then
        table.insert(windows, window(periodSeconds, periodKey, item.percentage, item.nextResetTime))
      end
    end
    if #windows == 0 then
      finish(requestGeneration, "zai", nil, "Z.ai returned no recognized quota windows")
      return
    end
    finish(requestGeneration, "zai", normalizeWindowResult(windows, tostring((payload.data or {}).level or "")), nil)
  end)
end

local function collect(requestGeneration, id)
  if id == "claude" then
    collectClaude(requestGeneration)
  elseif id == "codex" then
    collectCodex(requestGeneration)
  elseif id == "copilot" then
    collectCopilot(requestGeneration)
  elseif id == "zen" then
    collectZen(requestGeneration)
  elseif id == "zai" then
    collectZai(requestGeneration)
  else
    finish(requestGeneration, id, nil, "Unsupported provider")
  end
end

local function refreshAll()
  if refreshing then
    return
  end
  local ids = configuredProviderIds()
  generation += 1
  pending = #ids
  refreshing = pending > 0
  publish()
  if pending == 0 then
    noctalia.state.set("usage_last_refresh", os.time())
    return
  end
  local requestGeneration = generation
  for _, id in ipairs(ids) do
    collect(requestGeneration, id)
  end
end

local codexResetInFlight = false

local function publishCodexResetState(err)
  noctalia.state.set("codex_reset_in_flight", codexResetInFlight)
  noctalia.state.set("codex_reset_error", err or "")
end

local function consumeCodexReset()
  if codexResetInFlight then
    return
  end
  local codexData = providerData.codex
  local resetCredits = type(codexData) == "table" and codexData.reset_credits or nil
  if type(resetCredits) ~= "table" or (tonumber(resetCredits.applicable_available_count) or 0) <= 0 then
    local message = "No Codex rate-limit reset is usable right now"
    publishCodexResetState(message)
    noctalia.notifyError("Codex reset", message)
    return
  end
  local headers, authError = codexHeaders()
  if headers == nil then
    publishCodexResetState(authError)
    noctalia.notifyError("Codex reset", authError)
    return
  end
  local uuidContents = noctalia.readFile("/proc/sys/kernel/random/uuid")
  local requestId = noctalia.string.trim(uuidContents or "")
  if requestId == "" then
    local message = "Unable to create a reset request ID"
    publishCodexResetState(message)
    noctalia.notifyError("Codex reset", message)
    return
  end
  table.insert(headers, "Content-Type: application/json")
  codexResetInFlight = true
  publishCodexResetState(nil)
  httpJson({
    url = "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits/consume",
    method = "POST",
    headers = headers,
    body = noctalia.json.encode({ redeem_request_id = requestId }),
  }, function(payload, err)
    codexResetInFlight = false
    if payload == nil then
      publishCodexResetState(err)
      noctalia.notifyError("Codex reset", err or "Reset request failed")
      return
    end
    publishCodexResetState(nil)
    noctalia.notify("Codex reset", "Rate limits reset successfully")
    refreshAll()
  end)
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
  refreshAll()
end

function onIpc(event)
  if event == "refresh" then
    refreshAll()
  end
end

noctalia.state.watch("usage_refresh_request", function()
  refreshAll()
end)

noctalia.state.watch("codex_reset_request", function()
  consumeCodexReset()
end)

configureInterval()
publish()
refreshAll()
