--!nonstrict

noctalia.setUpdateInterval(1000)

local state = noctalia.state.get("hermes_state") or {
  bridge = { status = "offline", error = "" },
  hermes = { status = "unknown", model = "", provider = "" },
  session = { id = "", stored_id = "", running = false },
  messages = {},
  approval = { pending = false },
  summary = {},
}
local tick = 0
local requestInFlight = false
local bridgeStartTick = -1000
local gatewayStartTick = -1000
local lastCommandNonce = nil
local startedBridge = false
local bridgeScriptPath = nil

local function cfg(key)
  return noctalia.getConfig(key)
end

local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function bridgeUrl(path)
  return `http://{cfg("bridge_host")}:{cfg("bridge_port")}{path}`
end

local function tokenPath()
  local stateFile = tostring(cfg("state_file") or "~/.cache/noctalia-hermes/state.json")
  local path = stateFile:gsub("/[^/]+$", "/bridge.token")
  if path == stateFile then
    return "~/.cache/noctalia-hermes/bridge.token"
  end
  return path
end

local function bridgeToken()
  if cfg("client_only_mode") == true then
    return tostring(cfg("bridge_token") or "")
  end
  local contents = noctalia.readFile(tokenPath())
  return contents ~= nil and noctalia.string.trim(contents) or ""
end

local function headers(withJson)
  local result = { "Accept: application/json" }
  local token = bridgeToken()
  if token ~= "" then
    table.insert(result, "X-Bridge-Token: " .. token)
  end
  if withJson then
    table.insert(result, "Content-Type: application/json")
  end
  return result
end

local function publish(nextState)
  if type(nextState) == "table" then
    state = nextState.state or nextState
  end
  noctalia.state.set("hermes_state", state)
end

local function setOffline(message)
  state.bridge = state.bridge or {}
  state.bridge.status = "offline"
  state.bridge.error = message or "Bridge unavailable"
  publish()
end

local function request(method, path, payload, onDone)
  local body = nil
  if payload ~= nil then
    body = noctalia.json.encode(payload)
    if body == nil then
      onDone(nil, "Unable to encode request")
      return
    end
  end
  local accepted = noctalia.http({
    method = method,
    url = bridgeUrl(path),
    headers = headers(payload ~= nil),
    body = body,
  }, function(response)
    if not response.ok or response.status < 200 or response.status >= 300 then
      onDone(nil, `Bridge request failed: {response.status}`)
      return
    end
    local decoded = noctalia.json.decode(response.body or "")
    if type(decoded) ~= "table" then
      onDone(nil, "Invalid bridge response")
      return
    end
    onDone(decoded, nil)
  end)
  if not accepted then
    onDone(nil, "Unable to start bridge request")
  end
end

local function startBridge()
  if cfg("client_only_mode") == true or cfg("auto_start_bridge") == false then
    return
  end
  if tick - bridgeStartTick < 10 then
    return
  end
  bridgeStartTick = tick
  local dir = noctalia.pluginDir()
  if dir == nil then
    setOffline("Plugin directory unavailable")
    return
  end
  bridgeScriptPath = dir .. "/scripts/hermes_bridge.py"
  local command = table.concat({
    "python3",
    shellQuote(bridgeScriptPath),
    "--host", shellQuote(cfg("bridge_host")),
    "--port", shellQuote(cfg("bridge_port")),
    "--state-file", shellQuote(cfg("state_file")),
    "--hermes-home", shellQuote(cfg("hermes_home")),
    "--hermes-command", shellQuote(cfg("hermes_command")),
  }, " ")
  noctalia.log("hermes-agent: starting local bridge")
  startedBridge = noctalia.runAsync(command)
end

local function stopBridge()
  if not startedBridge or bridgeScriptPath == nil then
    return
  end
  noctalia.runAsync("pkill -f -- " .. shellQuote(bridgeScriptPath))
  startedBridge = false

end

local refreshState

local function maybeStartGateway()
  if cfg("auto_start_gateway") == false or tick - gatewayStartTick < 30 then
    return
  end
  local summary = state.summary or {}
  local gateway = summary.gateway or {}
  local status = gateway.status or "unknown"
  if status ~= "offline" and status ~= "stopped" then
    return
  end
  gatewayStartTick = tick
  request("POST", "/gateway/start", {}, function(data, err)
    if data ~= nil then
      publish(data)
    elseif err ~= nil then
      noctalia.log("hermes-agent: gateway start failed: " .. err)
    end
  end)
end

refreshState = function()
  if requestInFlight then
    return
  end
  requestInFlight = true
  request("GET", "/state", nil, function(data, err)
    requestInFlight = false
    if data ~= nil then
      publish(data)
      maybeStartGateway()
    else
      setOffline(err)
      startBridge()
    end
  end)
end

local function post(path, payload)
  request("POST", path, payload or {}, function(data, err)
    if data ~= nil then
      publish(data)
      refreshState()
    else
      setOffline(err)
    end
  end)
end

local function dispatch(command)
  if type(command) ~= "table" then
    return
  end
  local op = command.op
  local payload = type(command.payload) == "table" and command.payload or {}
  if op == "refresh" then
    refreshState()
  elseif op == "new_session" then
    post("/session/create", {})
  elseif op == "resume" then
    post("/session/resume", { session_id = payload.session_id or "" })
  elseif op == "prompt" then
    local function sendPrompt()
      post("/prompt", { text = payload.text or "" })
    end
    local session = state.session or {}
    if (session.id or session.stored_id or "") == "" then
      request("POST", "/session/create", {}, function(data, err)
        if data ~= nil then
          publish(data)
          sendPrompt()
        else
          setOffline(err)
        end
      end)
    else
      sendPrompt()
    end
  elseif op == "oneshot" then
    post("/oneshot", { text = payload.text or "" })
  elseif op == "interrupt" then
    post("/interrupt", {})
  elseif op == "approval" then
    post("/approval", { choice = payload.choice or "denied", all = payload.all == true })
  elseif op == "start_gateway" then
    gatewayStartTick = tick
    post("/gateway/start", {})
  end
end

function update()
  tick += 1
  local session = state.session or {}
  local interval = session.running == true and 2 or math.max(2, tonumber(cfg("status_poll_interval_sec")) or 30)
  if tick % interval == 0 then
    refreshState()
  end
end

function onConfigChanged()
  if cfg("client_only_mode") == true then
    stopBridge()
  end
  bridgeStartTick = -1000
  gatewayStartTick = -1000
  refreshState()
end

function onExit()
  stopBridge()
end

function onIpc(event, payload)
  local body = {}
  if type(payload) == "string" and payload ~= "" then
    body = noctalia.json.decode(payload) or { text = payload }
  end
  dispatch({ op = event, payload = body })
end

noctalia.state.watch("hermes_command", function(command)
  if type(command) ~= "table" or command.nonce == lastCommandNonce then
    return
  end
  lastCommandNonce = command.nonce
  dispatch(command)
end)

publish()
refreshState()
