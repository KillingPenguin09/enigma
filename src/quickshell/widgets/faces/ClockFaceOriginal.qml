import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 120
    property real minHeight: 64
    property real maxWidth: 600
    property real maxHeight: 200
    property real minAspect: 1.5
    property real maxAspect: 8.0
    property bool isRound: false

    Rectangle {
        id: bgContainer
        anchors.fill: parent
        color: ThemeBackend.surfaceVariant ?? ThemeBackend.surface0
        radius: ThemeBackend.borderRadius
        antialiasing: true

        SystemClock { id: clock; precision: SystemClock.Minutes }

        RowLayout {
            id: timeRow
            anchors.centerIn: parent
            spacing: 4

            Text {
                text: Qt.formatDateTime(clock.date, "ddd d MMM  HH:mm")
                font.family: ThemeBackend.fontFamily
                // Scale text down if window is small, otherwise cap at 24
                font.pixelSize: Math.min(24, Math.min(root.height * 0.4, root.width * 0.1))
                font.weight: Font.Normal
                color: ThemeBackend.text
                renderType: Text.NativeRendering
            }
        }
    }
}
