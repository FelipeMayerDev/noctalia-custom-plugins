import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Noctalia
import qs.Services.UI
import qs.Widgets
import "." as Local

Item {
  id: root

  property ShellScreen screen
  property var pluginApi
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0
  property string popupProvider: "claude"

  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)
  readonly property real iconSize: Style.toOdd(capsuleHeight * 0.44)
  readonly property real miniGaugeWidth: Math.max(3, Style.toOdd(root.iconSize * 0.25))
  readonly property bool iconOnlyMode: Local.AiUsageService.setting("iconOnlyMode", false)
  readonly property color textColor: Color.resolveColorKey(Local.AiUsageService.setting("textColor", "none"))
  readonly property var providers: Local.AiUsageService.providers()

  readonly property real contentWidth: isVertical ? capsuleHeight : Math.round(providerRow.implicitWidth + Style.margin2M)
  readonly property real contentHeight: isVertical ? Math.round(providerRow.implicitHeight + Style.margin2M) : capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  Component.onCompleted: {
    Local.AiUsageService.setPluginApi(pluginApi);
    Local.AiUsageService.registerComponent("bar-ai-usage:" + (screen?.name || "unknown"));
  }

  Component.onDestruction: Local.AiUsageService.unregisterComponent("bar-ai-usage:" + (screen?.name || "unknown"))

  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      Local.AiUsageService.refreshAll();
    }
  }

  NPopupContextMenu {
    id: contextMenu
    model: [
      { "label": "Refresh AI Usage", "action": "refresh", "icon": "refresh" },
      { "label": root.iconOnlyMode ? "Show full usage" : "Show icons only", "action": "toggle-icon-only", "icon": "eye" },
      { "label": "AI Usage Settings", "action": "settings", "icon": "settings" }
    ]
    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);
                   if (action === "refresh") {
                     Local.AiUsageService.refreshAll();
                   } else if (action === "toggle-icon-only") {
                     pluginApi.pluginSettings.iconOnlyMode = !root.iconOnlyMode;
                     pluginApi.saveSettings();
                   } else if (action === "settings") {
                     const manifest = PluginRegistry.getPluginManifest(pluginApi.pluginId);
                     if (manifest)
                       BarService.openPluginSettings(screen, manifest);
                   }
                 }
  }

  Rectangle {
    id: visualCapsule
    width: root.contentWidth
    height: root.contentHeight
    anchors.centerIn: parent
    radius: Style.radiusM
    color: Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    RowLayout {
      id: providerRow
      anchors.centerIn: parent
      spacing: isVertical ? Style.marginS : Style.marginM

      Repeater {
        model: root.providers

        delegate: MouseArea {
          id: providerMouse
          required property var modelData
          Layout.preferredWidth: tokenRow.implicitWidth
          Layout.preferredHeight: tokenRow.implicitHeight
          Layout.alignment: Qt.AlignCenter
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

          onClicked: mouse => {
                       if (mouse.button === Qt.RightButton) {
                         contextMenu.openAtItem(root, screen, providerMouse);
                         return;
                       }
                       if (mouse.button === Qt.MiddleButton) {
                         Local.AiUsageService.refreshAll();
                         return;
                       }
                       root.popupProvider = modelData.id;
                       if (Local.AiUsageService.setting("refreshOnOpen", true))
                         Local.AiUsageService.refreshIfStale(10000);
                       pluginApi.togglePanel(screen, root);
                     }
          onEntered: TooltipService.show(providerMouse, Local.AiUsageService.tooltipText(modelData.id), BarService.getTooltipDirection(root.screen?.name), Style.tooltipDelay, Settings.data.ui.fontFixed)
          onExited: TooltipService.hide(providerMouse)

          RowLayout {
            id: tokenRow
            anchors.centerIn: parent
            spacing: Style.marginXS

            Repeater {
              visible: !root.iconOnlyMode
              model: Local.AiUsageService.compactTokens(providerMouse.modelData.id)

              delegate: NText {
                required property var modelData
                required property int index
                visible: !root.iconOnlyMode
                text: String(modelData)
                family: Settings.data.ui.fontFixed
                pointSize: root.barFontSize
                applyUiScale: false
                color: index === 0 || index === 2 ? providerMouse.modelData.color : root.textColor
                verticalAlignment: Text.AlignVCenter
              }
            }

            RowLayout {
              visible: root.iconOnlyMode
              spacing: Style.marginXS

              NText {
                text: Local.AiUsageService.compactTokens(providerMouse.modelData.id)[0]
                family: Settings.data.ui.fontFixed
                pointSize: root.barFontSize
                applyUiScale: false
                color: providerMouse.modelData.color
                verticalAlignment: Text.AlignVCenter
              }

              NLinearGauge {
                Layout.alignment: Qt.AlignVCenter
                width: root.miniGaugeWidth
                height: root.iconSize
                orientation: Qt.Vertical
                ratio: Local.AiUsageService.providerPercentage(providerMouse.modelData.id) / 100
                fillColor: Local.AiUsageService.providerColor(providerMouse.modelData.id, providerMouse.modelData.color)
              }
            }
          }
        }
      }
    }
  }

  MouseArea {
    z: -1
    anchors.fill: parent
    acceptedButtons: Qt.RightButton
    onClicked: contextMenu.openAtItem(root, screen, root)
  }
}
