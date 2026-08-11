--!nonstrict

local function render()
  local host = tostring(noctalia.getConfig("host") or "")
  local user = tostring(noctalia.getConfig("user") or "")
  local target = host
  if user ~= "" and host ~= "" then
    target = user .. "@" .. host
  end
  barWidget.setGlyph("terminal-2")
  barWidget.setText(noctalia.getConfig("show_bar_text") == true and target or "")
  barWidget.setTooltip(target ~= "" and `Hermes SSH · {target}` or noctalia.tr("widget.not_configured"))
end

function update()
  render()
end

function onClick()
  noctalia.togglePanel("felipemayerdev/hermes-ssh-chat:terminal-panel")
end

function onRightClick()
  noctalia.openSettings()
end

render()
