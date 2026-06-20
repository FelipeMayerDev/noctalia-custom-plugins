import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import "." as Local

ColumnLayout {
  id: root
  spacing: Style.marginM

  property var pluginApi
  property string zaiToken: ""
  property string tokenStatus: ""
  property string cookieStatus: ""
  property bool loadedToken: false
  property var cookieSources: [{ "key": "auto", "name": "Auto-detect" }]
  property string claudeCookieSource: "auto"
  property string codexCookieSource: "auto"

  readonly property var allProviders: Local.AiUsageService.allProviders

  Component.onCompleted: {
    Local.AiUsageService.setPluginApi(pluginApi);
    loadZaiToken();
    scanCookieSources();
  }

  function enabledProviderIds() {
    const value = pluginApi.pluginSettings.enabledProviders;
    if (Array.isArray(value))
      return value;
    if (typeof value === "string")
      return value.split(",").filter(s => s.length > 0);
    return ["claude", "codex"];
  }

  function providerEnabled(id) {
    return enabledProviderIds().indexOf(id) !== -1;
  }

  function setProviderEnabled(id, enabled) {
    let list = enabledProviderIds().filter(p => p !== id);
    if (enabled)
      list.push(id);
    pluginApi.pluginSettings.enabledProviders = list;
    saveSettings();
  }

  function saveSettings() {
    pluginApi.saveSettings();
    Local.AiUsageService.refreshAll();
  }

  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'";
  }

  function runShell(command, callback) {
    const proc = Qt.createQmlObject("import QtQuick; import Quickshell.Io; Process { stdout: StdioCollector {} }", root, "AiUsageSettingsProcess");
    proc.command = ["sh", "-c", command];
    proc.exited.connect(function(exitCode) {
      if (callback)
        callback(exitCode, String(proc.stdout.text || ""));
      proc.destroy();
    });
    proc.running = true;
  }

  function loadZaiToken() {
    runShell("cat ~/.config/plasma-ai-usage-panel/zai.conf 2>/dev/null", function(_exitCode, output) {
      const match = output.match(/ZAI_TOKEN\s*=\s*(\S+)/);
      if (match)
        root.zaiToken = match[1];
      root.loadedToken = true;
    });
  }

  function saveZaiToken() {
    const content = "ZAI_TOKEN=" + root.zaiToken + "\n";
    const command = "mkdir -p ~/.config/plasma-ai-usage-panel && umask 077 && printf %s " + shellQuote(content) + " > ~/.config/plasma-ai-usage-panel/zai.conf";
    runShell(command, function(exitCode) {
      root.tokenStatus = exitCode === 0 ? "Saved" : "Save failed: " + exitCode;
      statusTimer.restart();
      Local.AiUsageService.refreshAll();
    });
  }

  function sourceLabelForKey(key) {
    for (let i = 0; i < root.cookieSources.length; i++) {
      if (root.cookieSources[i].key === key)
        return root.cookieSources[i].name;
    }
    return key;
  }

  function scanCookieSources() {
    runShell("export PATH=\"$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin:$PATH\"; ai-cookie-source --json", function(exitCode, output) {
      if (exitCode !== 0) {
        root.cookieStatus = "Cookie scan failed";
        return;
      }

      try {
        const data = JSON.parse(output);
        const models = [{ "key": "auto", "name": "Auto-detect" }];
        const sources = data.sources || [];
        for (let i = 0; i < sources.length; i++) {
          const s = sources[i];
          const cClaude = (s.counts && s.counts["claude.ai"]) || 0;
          const cCodex = (s.counts && s.counts["chatgpt.com"]) || 0;
          const dClaude = (s.decrypted && s.decrypted["claude.ai"]) || 0;
          const dCodex = (s.decrypted && s.decrypted["chatgpt.com"]) || 0;
          models.push({
                        "key": s.key,
                        "name": s.name + " (Claude " + dClaude + "/" + cClaude + ", Codex " + dCodex + "/" + cCodex + ")"
                      });
        }
        root.cookieSources = models;

        const configured = data.configured || {};
        if (configured["claude.ai"] && configured["claude.ai"].cookie_file)
          root.claudeCookieSource = configured["claude.ai"].cookie_file + "|" + (configured["claude.ai"].key_file || "");
        if (configured["chatgpt.com"] && configured["chatgpt.com"].cookie_file)
          root.codexCookieSource = configured["chatgpt.com"].cookie_file + "|" + (configured["chatgpt.com"].key_file || "");

        root.cookieStatus = "Cookie sources scanned";
        cookieStatusTimer.restart();
      } catch (e) {
        root.cookieStatus = "Cookie scan parse failed";
      }
    });
  }

  function saveCookieSource(domain, key) {
    let cookieFile = "auto";
    let keyFile = "";
    let label = "Auto-detect";
    if (key !== "auto") {
      const parts = key.split("|");
      cookieFile = parts[0] || "auto";
      keyFile = parts[1] || "";
      label = sourceLabelForKey(key);
    }
    const command = "export PATH=\"$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin:$PATH\"; ai-cookie-source --save "
      + shellQuote(domain) + " " + shellQuote(cookieFile) + " " + shellQuote(keyFile) + " " + shellQuote(label);
    runShell(command, function(exitCode) {
      root.cookieStatus = exitCode === 0 ? "Cookie source saved" : "Cookie source save failed";
      cookieStatusTimer.restart();
      Local.AiUsageService.refreshAll();
    });
  }

  Timer {
    id: statusTimer
    interval: 2500
    onTriggered: root.tokenStatus = ""
  }

  Timer {
    id: cookieStatusTimer
    interval: 2500
    onTriggered: root.cookieStatus = ""
  }

  NText {
    text: "AI Usage Panel"
    pointSize: Style.fontSizeL
    font.weight: Style.fontWeightBold
    color: Color.mPrimary
  }

  NText {
    Layout.fillWidth: true
    text: "Uses the existing plasma-ai-usage-panel CLI helpers: claude-usage, codex-usage, copilot-usage, zen-balance, zai-usage."
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
  }

  NDivider { Layout.fillWidth: true }

  Repeater {
    model: root.allProviders

    delegate: ColumnLayout {
      required property var modelData
      Layout.fillWidth: true
      spacing: Style.marginXS

      NToggle {
        label: modelData.label
        description: modelData.id === "zai" ? "Requires Z.ai API key below." : "Requires logged-in browser cookies for this provider."
        checked: root.providerEnabled(modelData.id)
        onToggled: checked => root.setProviderEnabled(modelData.id, checked)
      }
    }
  }

  NDivider { Layout.fillWidth: true }

  NText {
    text: "Cookie sources"
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mPrimary
  }

  NText {
    Layout.fillWidth: true
    text: "Pick the Chrome/Brave profile that contains each login. Numbers show decryptable/total cookies for that domain."
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
  }

  NComboBox {
    Layout.fillWidth: true
    label: "Claude cookies"
    model: root.cookieSources
    currentKey: root.claudeCookieSource
    onSelected: key => {
                  root.claudeCookieSource = key;
                  root.saveCookieSource("claude.ai", key);
                }
  }

  NComboBox {
    Layout.fillWidth: true
    label: "Codex cookies"
    model: root.cookieSources
    currentKey: root.codexCookieSource
    onSelected: key => {
                  root.codexCookieSource = key;
                  root.saveCookieSource("chatgpt.com", key);
                }
  }

  RowLayout {
    Layout.fillWidth: true
    Item { Layout.fillWidth: true }
    NText {
      text: root.cookieStatus
      visible: root.cookieStatus.length > 0
      color: Color.mPrimary
    }
    NButton {
      text: "Rescan cookies"
      icon: "refresh"
      onClicked: root.scanCookieSources()
    }
  }

  NDivider { Layout.fillWidth: true }

  NToggle {
    label: "Icons only"
    description: "Show only provider icons with a vertical usage gauge, like System Monitor compact mode."
    checked: pluginApi.pluginSettings.iconOnlyMode === true
    onToggled: checked => {
                 pluginApi.pluginSettings.iconOnlyMode = checked;
                 saveSettings();
               }
  }

  NSpinBox {
    label: "Refresh interval"
    description: "Seconds between automatic refreshes."
    from: 30
    to: 3600
    stepSize: 30
    value: Number(pluginApi.pluginSettings.refreshIntervalSeconds || 120)
    suffix: "s"
    onValueChanged: {
      pluginApi.pluginSettings.refreshIntervalSeconds = value;
      saveSettings();
    }
  }

  NToggle {
    label: "Show reset time"
    description: "Show reset ETA in bar chips."
    checked: pluginApi.pluginSettings.showResetTime !== false
    onToggled: checked => {
                 pluginApi.pluginSettings.showResetTime = checked;
                 saveSettings();
               }
  }

  NToggle {
    label: "Refresh on open"
    description: "Refresh when opening panel, rate-limited to 10 seconds."
    checked: pluginApi.pluginSettings.refreshOnOpen !== false
    onToggled: checked => {
                 pluginApi.pluginSettings.refreshOnOpen = checked;
                 saveSettings();
               }
  }

  NDivider { Layout.fillWidth: true }

  NTextInput {
    id: tokenInput
    Layout.fillWidth: true
    label: "Z.ai API key"
    description: "Saved to ~/.config/plasma-ai-usage-panel/zai.conf for compatibility with zai-usage."
    placeholderText: root.loadedToken ? "API key from z.ai" : "Loading..."
    text: root.zaiToken
    inputItem.echoMode: TextInput.Password
    onEditingFinished: root.zaiToken = text
    onAccepted: {
      root.zaiToken = text;
      root.saveZaiToken();
    }
  }

  RowLayout {
    Layout.fillWidth: true
    Item { Layout.fillWidth: true }

    NText {
      text: root.tokenStatus
      visible: root.tokenStatus.length > 0
      color: root.tokenStatus === "Saved" ? Color.mPrimary : Color.mError
    }

    NButton {
      text: "Save Z.ai key"
      icon: "check"
      enabled: tokenInput.text.length > 0
      onClicked: {
        root.zaiToken = tokenInput.text;
        root.saveZaiToken();
      }
    }
  }
}
