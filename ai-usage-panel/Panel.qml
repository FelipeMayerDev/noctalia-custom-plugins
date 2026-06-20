import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import "." as Local

Item {
  id: root

  property var pluginApi
  property real contentPreferredWidth: Math.round(420 * Style.uiScaleRatio)
  property real contentPreferredHeight: mainColumn.implicitHeight + Style.margin2L
  property bool allowAttach: true

  Component.onCompleted: {
    Local.AiUsageService.setPluginApi(pluginApi);
    Local.AiUsageService.registerComponent("panel-ai-usage");
  }

  Component.onDestruction: Local.AiUsageService.unregisterComponent("panel-ai-usage")

  ColumnLayout {
    id: mainColumn
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    NBox {
      Layout.fillWidth: true
      implicitHeight: headerRow.implicitHeight + Style.margin2M

      RowLayout {
        id: headerRow
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NIcon {
          icon: "device-analytics"
          pointSize: Style.fontSizeXXL
          color: Color.mPrimary
        }

        NText {
          text: "AI Usage"
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
          Layout.fillWidth: true
        }

        NButton {
          text: Local.AiUsageService.refreshing ? "Refreshing" : "Refresh"
          icon: "refresh"
          enabled: !Local.AiUsageService.refreshing
          onClicked: Local.AiUsageService.refreshAll()
        }
      }
    }

    Repeater {
      model: Local.AiUsageService.providers()

      delegate: NBox {
        required property var modelData
        Layout.fillWidth: true
        implicitHeight: providerColumn.implicitHeight + Style.margin2M

        ColumnLayout {
          id: providerColumn
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.marginM
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NText {
              text: modelData.label
              pointSize: Style.fontSizeM
              font.weight: Style.fontWeightBold
              color: modelData.color
              Layout.fillWidth: true
            }

            NText {
              text: Local.AiUsageService.compactTokens(modelData.id).join(" ")
              pointSize: Style.fontSizeS
              family: Settings.data.ui.fontFixed
              color: Color.mOnSurfaceVariant
            }
          }

          NText {
            Layout.fillWidth: true
            text: Local.AiUsageService.tooltipText(modelData.id)
            pointSize: Style.fontSizeS
            family: Settings.data.ui.fontFixed
            color: Color.mOnSurface
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
