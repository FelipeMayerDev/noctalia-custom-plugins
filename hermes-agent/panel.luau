--!nonstrict

local state = noctalia.state.get("hermes_state") or {}
local composerText = ""
local composerRevision = 0
local render

local function tr(key)
  return noctalia.tr(key)
end

local function sendCommand(op, payload)
  local nonce = (tonumber(noctalia.state.get("hermes_command_nonce")) or 0) + 1
  noctalia.state.set("hermes_command_nonce", nonce)
  noctalia.state.set("hermes_command", { nonce = nonce, op = op, payload = payload or {} })
end

local function status()
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

local function statusLabel(value)
  local labels = {
    offline = tr("status.offline"),
    idle = tr("status.idle"),
    busy = tr("status.busy"),
    attention = tr("status.attention"),
    degraded = tr("status.degraded"),
    error = tr("status.error"),
    unknown = tr("status.unknown"),
  }
  return labels[value] or labels.unknown
end

local function statusColor(value)
  if value == "offline" or value == "error" then
    return "error"
  elseif value == "attention" then
    return "#f59e0b"
  elseif value == "degraded" then
    return "#f97316"
  end
  return "primary"
end

local function messageNode(message, index)
  local role = tostring(message.role or message.type or "assistant")
  local fromUser = role == "user"
  local content = tostring(message.content or message.text or "")
  return ui.column({
    key = `message-{index}`,
    gap = 6,
    padding = 12,
    fill = fromUser and "primary/0.16" or "surface_variant/0.55",
    radius = 10,
  }, {
    ui.row({ align = "center", gap = 6 }, {
      ui.glyph({ name = fromUser and "user" or "sparkles", size = 16, color = fromUser and "primary" or "secondary" }),
      ui.label({ text = fromUser and tr("bubble.you") or tr("bubble.hermes"), fontWeight = "bold" }),
    }),
    ui.label({ text = content, maxLines = 100 }),
  })
end

local function transcript()
  local messages = state.messages or {}
  local nodes = {}
  if #messages == 0 then
    local online = status() ~= "offline"
    table.insert(nodes, ui.column({ align = "center", gap = 10, padding = 24 }, {
      ui.glyph({ name = online and "message-circle" or "power", size = 30, color = "on_surface_variant" }),
      ui.label({ text = online and tr("panel.noSession") or tr("panel.bridgeOffline"), color = "on_surface_variant", textAlign = "center" }),
    }))
  else
    for index, message in ipairs(messages) do
      table.insert(nodes, messageNode(message, index))
    end
  end
  return ui.scroll({ flexGrow = 1, gap = 10 }, nodes)
end

local function approvalCard()
  local approval = state.approval or {}
  if approval.pending ~= true then
    return ui.box({ visible = false })
  end
  local message = tostring(approval.message or approval.tool_name or tr("panel.approvalRequired"))
  return ui.column({ gap = 10, padding = 12, fill = "error/0.10", border = "error/0.45", borderWidth = 1, radius = 10 }, {
    ui.label({ text = tr("panel.approvalRequired"), fontWeight = "bold", color = "error" }),
    ui.label({ text = message, maxLines = 5 }),
    ui.row({ gap = 8, justify = "end" }, {
      ui.button({ text = tr("panel.deny"), variant = "destructive", onClick = "onDeny" }),
      ui.button({ text = tr("panel.approve"), variant = "primary", onClick = "onApprove" }),
      ui.button({ text = tr("panel.approveSession"), variant = "secondary", onClick = "onApproveSession" }),
    }),
  })
end

local function activityLine()
  local activity = ((state.summary or {}).activity or {})
  local count = tonumber(activity.tool_events) or 0
  local session = state.session or {}
  if count == 0 or (noctalia.getConfig("show_tool_activity") ~= true and session.running ~= true) then
    return ui.box({ visible = false })
  end
  local running = tonumber(activity.running_tools) or 0
  local text = running > 0 and `{running} {tr("panel.backgroundRunning")}` or `{count} {tr("panel.backgroundActions")} · {tr("panel.lastAction")}: {activity.last_tool or "tool"}`
  return ui.row({ gap = 8, padding = 8, fill = "surface_variant/0.6", radius = 8 }, {
    ui.glyph({ name = session.running and "loader" or "activity", size = 15, color = "on_surface_variant" }),
    ui.label({ text = text, color = "on_surface_variant", maxLines = 1 }),
  })
end

render = function()
  local currentStatus = status()
  local hermes = state.hermes or {}
  local model = tostring(hermes.model or "")
  local provider = tostring(hermes.provider or "")
  local modelLabel = model ~= "" and (provider ~= "" and provider .. " / " .. model or model) or tr("panel.noModel")
  local session = state.session or {}
  local busy = session.running == true or hermes.status == "busy"
  panel.render(ui.column({ flexGrow = 1, gap = 12 }, {
    ui.row({ align = "center", gap = 10 }, {
      ui.glyph({ name = "sparkles", size = 24, color = statusColor(currentStatus) }),
      ui.column({ gap = 2, flexGrow = 1 }, {
        ui.label({ text = tr("panel.title"), fontSize = 18, fontWeight = "bold" }),
        ui.label({ text = modelLabel, color = "on_surface_variant", maxLines = 1 }),
      }),
      ui.label({ text = statusLabel(currentStatus), color = statusColor(currentStatus), fontWeight = "bold" }),
      ui.button({ glyph = "refresh", variant = "ghost", tooltip = tr("bar.refresh"), onClick = "onRefresh" }),
      ui.button({ glyph = "close", variant = "ghost", tooltip = tr("panel.close"), onClick = "onCloseClicked" }),
    }),
    approvalCard(),
    activityLine(),
    transcript(),
    ui.row({ align = "center", gap = 8 }, {
      ui.button({ text = tr("panel.newSession"), glyph = "plus", onClick = "onNewSession" }),
      ui.input({
        key = `composer-{composerRevision}`,
        value = composerText,
        placeholder = tr("panel.placeholder"),
        height = 58,
        flexGrow = 1,
        enabled = currentStatus ~= "offline",
        onChange = "onComposerChanged",
        onSubmit = "onComposerSubmit",
      }),
      ui.button({
        text = busy and tr("panel.interrupt") or tr("panel.send"),
        glyph = busy and "octagon" or "send",
        variant = busy and "destructive" or "primary",
        enabled = currentStatus ~= "offline" and (busy or composerText ~= ""),
        onClick = busy and "onInterrupt" or "onSendClicked",
      }),
    }),
  }))
end

local function submit(value)
  local text = noctalia.string.trim(tostring(value or composerText))
  if text == "" then
    return
  end
  sendCommand("prompt", { text = text })
  composerText = ""
  composerRevision += 1
  render()
end

function onOpen()
  render()
  sendCommand("refresh")
end

function onCloseClicked()
  panel.close()
end

function onRefresh()
  sendCommand("refresh")
end

function onNewSession()
  sendCommand("new_session")
end

function onInterrupt()
  sendCommand("interrupt")
end

function onApprove()
  sendCommand("approval", { choice = "approved", all = false })
end

function onApproveSession()
  sendCommand("approval", { choice = "approved", all = true })
end

function onDeny()
  sendCommand("approval", { choice = "denied", all = false })
end

function onComposerChanged(value)
  composerText = tostring(value or "")
end

function onComposerSubmit(value)
  submit(value)
end

function onSendClicked()
  submit(composerText)
end

noctalia.state.watch("hermes_state", function(value)
  state = type(value) == "table" and value or {}
  render()
end)
