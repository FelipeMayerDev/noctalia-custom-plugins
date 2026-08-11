--!nonstrict

local lastQuery = ""

local function sendCommand(op, payload)
  local nonce = (tonumber(noctalia.state.get("hermes_command_nonce")) or 0) + 1
  noctalia.state.set("hermes_command_nonce", nonce)
  noctalia.state.set("hermes_command", { nonce = nonce, op = op, payload = payload or {} })
end

local function openPanel()
  noctalia.togglePanel("felipemayerdev/hermes-agent:chat-panel")
end

function onQuery(text)
  lastQuery = noctalia.string.trim(text or "")
  local results = {}
  if lastQuery ~= "" then
    table.insert(results, {
      id = "ask",
      title = noctalia.tr("launcher.ask"),
      subtitle = lastQuery,
      glyph = "send",
      score = 1000,
    })
  else
    table.insert(results, {
      id = "hint",
      title = noctalia.tr("launcher.typePrompt"),
      subtitle = "/hermes plan the next change",
      glyph = "message-circle",
      score = 1000,
    })
  end
  table.insert(results, {
    id = "open",
    title = noctalia.tr("launcher.openPanel"),
    subtitle = noctalia.tr("launcher.openPanelDescription"),
    glyph = "panel-right-open",
    score = 950,
  })
  table.insert(results, {
    id = "new",
    title = noctalia.tr("launcher.newSession"),
    subtitle = noctalia.tr("launcher.newSessionDescription"),
    glyph = "plus",
    score = 900,
  })
  table.insert(results, {
    id = "resume",
    title = noctalia.tr("launcher.resumeLatest"),
    subtitle = noctalia.tr("launcher.resumeLatestDescription"),
    glyph = "history",
    score = 850,
  })
  launcher.setResults(text, results)
end

function onActivate(id)
  if id == "ask" and lastQuery ~= "" then
    sendCommand("oneshot", { text = lastQuery })
    openPanel()
  elseif id == "open" then
    openPanel()
  elseif id == "new" then
    sendCommand("new_session")
    openPanel()
  elseif id == "resume" then
    local session = (noctalia.state.get("hermes_state") or {}).session or {}
    local storedId = session.stored_id or ""
    if storedId == "" then
      noctalia.notify(noctalia.tr("panel.title"), noctalia.tr("panel.noSession"))
      return
    end
    sendCommand("resume", { session_id = storedId })
    openPanel()
  end
end
