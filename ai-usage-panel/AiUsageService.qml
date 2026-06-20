pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property var pluginApi: null
  property var providerData: ({})
  property bool refreshing: false
  property real lastRefreshMs: 0
  property var _registered: ({})

  readonly property int registeredCount: Object.keys(_registered).length
  readonly property bool shouldRun: registeredCount > 0
  readonly property int refreshIntervalMs: Math.max(30, Number(setting("refreshIntervalSeconds", 120))) * 1000

  readonly property var allProviders: [
    { id: "claude", label: "Claude", command: "claude-usage --json", color: "#DE7356" },
    { id: "codex", label: "Codex", command: "codex-usage --json", color: "#74AA9C" },
    { id: "copilot", label: "Copilot", command: "copilot-usage --json", color: "#8b5cf6" },
    { id: "zen", label: "OpenCode Zen", command: "zen-balance --json", color: "#DE7356" },
    { id: "zai", label: "Z.ai", command: "zai-usage --json", color: "#126EF4" }
  ]

  function setPluginApi(api) {
    if (!api)
      return;
    root.pluginApi = api;
  }

  function setting(key, fallback) {
    if (!root.pluginApi || !root.pluginApi.pluginSettings)
      return fallback;
    const value = root.pluginApi.pluginSettings[key];
    return value === undefined ? fallback : value;
  }

  function enabledProviderIds() {
    const value = setting("enabledProviders", ["claude", "codex"]);
    if (Array.isArray(value))
      return value;
    if (typeof value === "string")
      return value.split(",").filter(s => s.length > 0);
    return ["claude", "codex"];
  }

  function providers() {
    const enabled = enabledProviderIds();
    return allProviders.filter(p => enabled.indexOf(p.id) !== -1);
  }

  function providerById(id) {
    for (let i = 0; i < allProviders.length; i++) {
      if (allProviders[i].id === id)
        return allProviders[i];
    }
    return allProviders[0];
  }

  function registerComponent(componentId) {
    root._registered[componentId] = true;
    root._registered = Object.assign({}, root._registered);
    if (root.registeredCount === 1)
      refreshAll();
  }

  function unregisterComponent(componentId) {
    delete root._registered[componentId];
    root._registered = Object.assign({}, root._registered);
  }

  function stripPango(value) {
    if (!value)
      return "";
    return String(value).replace(/<[^>]+>/g, "");
  }

  function compactTokens(providerId) {
    const provider = providerById(providerId);
    const data = providerData[providerId];
    if (!data)
      return [provider.label, "..."];
    if (data.error || data.class === "critical")
      return [provider.label, "!"];

    let clean = stripPango(data.text || provider.label).trim();
    let tokens = clean.split(/\s+/).filter(t => t.length > 0);
    if (!setting("showResetTime", true) && tokens.length >= 4)
      tokens = tokens.slice(0, 2);
    return tokens.length > 0 ? tokens : [provider.label, "?"];
  }

  function providerPercentage(providerId) {
    const data = providerData[providerId];
    if (!data || data.error)
      return 0;
    const value = Number(data.percentage);
    if (isNaN(value))
      return 0;
    return Math.max(0, Math.min(100, value));
  }

  function providerColor(providerId, fallbackColor) {
    const pct = providerPercentage(providerId);
    if (pct >= 90)
      return "#ff5555";
    if (pct >= 80)
      return "#e6b450";
    return fallbackColor;
  }

  function tooltipText(providerId) {
    const data = providerData[providerId];
    if (!data)
      return "Loading...";
    if (data.error)
      return data.raw || "Could not fetch usage data.";
    if (!data.tooltip)
      return stripPango(data.text || "");

    const lines = stripPango(data.tooltip).split("\n");
    const out = [];
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (line.trim().toLowerCase().indexOf("click") === 0)
        continue;
      if (line.match(/^[━─=]+$/))
        continue;
      out.push(line);
    }
    return out.join("\n").trim();
  }

  function refreshAll() {
    const list = providers();
    root.lastRefreshMs = Date.now();
    root.refreshing = list.length > 0;
    if (list.length === 0) {
      root.refreshing = false;
      return;
    }
    for (let i = 0; i < list.length; i++)
      refreshProvider(list[i]);
  }

  function refreshIfStale(maxAgeMs) {
    if (Date.now() - root.lastRefreshMs >= maxAgeMs)
      refreshAll();
  }

  function commandWithPath(command) {
    return "export PATH=\"$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin:$PATH\"; " + command;
  }

  function refreshProvider(provider) {
    const proc = Qt.createQmlObject("import QtQuick; import Quickshell.Io; Process { stdout: StdioCollector {} }", root, "AiUsageProcess");
    proc.command = ["sh", "-c", commandWithPath(provider.command)];
    proc.exited.connect(function(exitCode) {
      const stdout = String(proc.stdout.text || "").trim();
      let parsed = null;
      try {
        parsed = JSON.parse(stdout);
      } catch (e) {
        parsed = { error: true, raw: stdout || ("exit " + exitCode) };
      }

      if (exitCode !== 0 && !parsed.class)
        parsed.error = true;

      const copy = Object.assign({}, root.providerData);
      copy[provider.id] = parsed;
      root.providerData = copy;
      proc.destroy();
      root.refreshing = false;
    });
    proc.running = true;
  }

  Timer {
    interval: root.refreshIntervalMs
    repeat: true
    running: root.shouldRun
    triggeredOnStart: true
    onTriggered: root.refreshAll()
  }
}
