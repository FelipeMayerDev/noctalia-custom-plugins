--!nonstrict

local host = tostring(noctalia.getConfig("host") or "")
local port = tonumber(noctalia.getConfig("port")) or 22
local user = tostring(noctalia.getConfig("user") or "")
local remoteCommand = tostring(noctalia.getConfig("remote_command") or "hermes")
local statusText = ""
local render

local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function connectionCommand()
  local target = host
  if user ~= "" then
    target = user .. "@" .. host
  end
  local parts = { "ssh", "-p", tostring(math.clamp(port, 1, 65535)) }
  local identity = tostring(noctalia.getConfig("identity_file") or "")
  if identity ~= "" then
    table.insert(parts, "-i")
    table.insert(parts, shellQuote(noctalia.expandPath(identity)))
  end
  local extra = noctalia.string.trim(tostring(noctalia.getConfig("extra_ssh_args") or ""))
  if extra ~= "" then
    table.insert(parts, extra)
  end
  table.insert(parts, "-t")
  table.insert(parts, shellQuote(target))
  table.insert(parts, shellQuote(remoteCommand))
  return table.concat(parts, " ")
end

render = function()
  local ready = noctalia.string.trim(host) ~= ""
  panel.render(ui.column({ flexGrow = 1, gap = 16 }, {
    ui.row({ align = "center", gap = 10 }, {
      ui.glyph({ name = "terminal-2", size = 24, color = "primary" }),
      ui.column({ gap = 2, flexGrow = 1 }, {
        ui.label({ text = noctalia.tr("panel.title"), fontSize = 18, fontWeight = "bold" }),
        ui.label({ text = noctalia.tr("panel.subtitle"), color = "on_surface_variant", maxLines = 2 }),
      }),
      ui.button({ glyph = "close", variant = "ghost", tooltip = noctalia.tr("panel.close"), onClick = "onCloseClicked" }),
    }),
    ui.separator(),
    ui.column({ gap = 8 }, {
      ui.label({ text = noctalia.tr("settings.host.label"), color = "on_surface_variant" }),
      ui.input({ key = "host", value = host, placeholder = "server.example.com", onChange = "onHostChanged" }),
    }),
    ui.row({ gap = 10 }, {
      ui.column({ gap = 8, flexGrow = 1 }, {
        ui.label({ text = noctalia.tr("settings.user.label"), color = "on_surface_variant" }),
        ui.input({ key = "user", value = user, placeholder = "user", onChange = "onUserChanged" }),
      }),
      ui.column({ gap = 8, width = 120 }, {
        ui.label({ text = noctalia.tr("settings.port.label"), color = "on_surface_variant" }),
        ui.input({ key = "port", value = tostring(port), placeholder = "22", onChange = "onPortChanged" }),
      }),
    }),
    ui.column({ gap = 8 }, {
      ui.label({ text = noctalia.tr("settings.remote_command.label"), color = "on_surface_variant" }),
      ui.input({ key = "command", value = remoteCommand, placeholder = "hermes", onChange = "onCommandChanged", onSubmit = "onConnect" }),
    }),
    ui.spacer({ flexGrow = 1 }),
    ui.label({ text = statusText, color = statusText == "" and "on_surface_variant" or "primary", textAlign = "center" }),
    ui.button({
      text = noctalia.tr("panel.connect"),
      glyph = "plug-connected",
      variant = "primary",
      enabled = ready,
      onClick = "onConnect",
    }),
    ui.label({ text = noctalia.tr("panel.auth_note"), color = "on_surface_variant", textAlign = "center", maxLines = 3 }),
  }))
end

function onOpen()
  render()
end

function onHostChanged(value)
  host = tostring(value or "")
  render()
end

function onUserChanged(value)
  user = tostring(value or "")
end

function onPortChanged(value)
  port = math.clamp(tonumber(value) or 22, 1, 65535)
end

function onCommandChanged(value)
  remoteCommand = tostring(value or "hermes")
end

function onConnect()
  if noctalia.string.trim(host) == "" then
    statusText = noctalia.tr("panel.missing_host")
    render()
    return
  end
  local accepted = noctalia.runInTerminal(connectionCommand())
  statusText = accepted and noctalia.tr("panel.launched") or noctalia.tr("panel.launch_failed")
  render()
end

function onCloseClicked()
  panel.close()
end
