import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../singletons/audio"
import "../singletons/theme"

PanelWindow {
    id: root
    
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.namespace: "overlay"
    WlrLayershell.layer: WlrLayer.Bottom
    exclusionMode: ExclusionMode.Ignore
    
    color: "transparent"

    property bool isOccupied: false

    Process {
        id: activeWsCheck
        command: ["sh", "-c", "hyprctl activeworkspace -j | grep -o '\"windows\": [0-9]*' | grep -o '[0-9]*'"]
        stdout: SplitParser {
            onRead: line => {
                var w = parseInt(line.trim());
                if (!isNaN(w)) {
                    root.isOccupied = (w > 0);
                }
            }
        }
    }

    Timer {
        interval: 300
        running: true
        repeat: true
        onTriggered: {
            if (!activeWsCheck.running) {
                activeWsCheck.running = true;
            }
        }
    }

    Item {
        id: visContainer
        anchors.fill: parent
        
        visible: opacity > 0
        opacity: root.isOccupied ? 0.0 : 1.0        
            
        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
        }

        // Clock Component
        ColumnLayout {
            anchors.left: parent.left
            anchors.leftMargin: 120
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -40
            spacing: -10

            Text {
                id: timeText
                font.family: ThemeBackend.fontFamily
                font.pixelSize: 130
                font.weight: Font.Bold
                color: "white"
                Layout.alignment: Qt.AlignLeft
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.3)
            }

            Text {
                id: dateText
                font.family: ThemeBackend.fontFamily
                font.pixelSize: 28
                font.weight: Font.Medium
                color: Qt.rgba(1, 1, 1, 0.8)
                Layout.alignment: Qt.AlignLeft
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.3)
            }
        }
        
        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                var date = new Date()
                timeText.text = date.toLocaleTimeString(Qt.locale(), "HH:mm")
                dateText.text = date.toLocaleDateString(Qt.locale(), "dddd, dd MMMM")
            }
            Component.onCompleted: triggered()
        }

        // Visualizer Component
        property bool isVisVisible: root.visible && visContainer.opacity > 0
        onIsVisVisibleChanged: {
            if (isVisVisible) Cava.registerConsumer();
            else Cava.unregisterConsumer();
        }
        Component.onCompleted: {
            if (isVisVisible) Cava.registerConsumer();
        }
        Component.onDestruction: {
            if (isVisVisible) Cava.unregisterConsumer();
        }

        property int activeBars: 60
        property real actualBarWidth: 3.5
        property real barSpacing: (635 - (activeBars * actualBarWidth)) / Math.max(1, activeBars - 1)

        property var rawBarLevels: Cava.barLevels
        property var processedBars: {
            let source = rawBarLevels;
            let count = activeBars;
            let out = [];

            if (!source || source.length === 0) {
                for (let i = 0; i < count; i++) out.push(0.0);
                return out;
            }

            let srcLen = source.length;
            let half = (count - 1) / 2;

            for (let i = 0; i < count; i++) {
                let distFromCenter = Math.abs(i - half);
                let norm = half > 0 ? (distFromCenter / half) : 0;
                let pos = Math.pow(norm, 1.25) * (srcLen - 1);
                let idx0 = Math.floor(pos);
                let idx1 = Math.min(srcLen - 1, idx0 + 1);
                let frac = pos - idx0;

                let v0 = source[idx0] || 0.0;
                let v1 = source[idx1] || 0.0;
                let rawVal = v0 + (v1 - v0) * frac;

                let val = rawVal < 0.03 ? 0.0 : Math.pow((rawVal - 0.03) / 0.97, 1.15);
                val = Math.max(0.0, Math.min(1.0, val));

                let edgeNorm = Math.sin((i / Math.max(1, count - 1)) * Math.PI);
                let edgeFactor = Math.min(1.0, edgeNorm * 2.0);
                edgeFactor = edgeFactor * edgeFactor * (3.0 - 2.0 * edgeFactor);
                val *= edgeFactor;

                out.push(val);
            }

            return out;
        }

        Row {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 330
            anchors.bottomMargin: 380
            width: 635
            height: 180
            
            spacing: visContainer.barSpacing
            
            Repeater {
                model: visContainer.activeBars
                
                Rectangle {
                    width: visContainer.actualBarWidth
                    height: Math.max(4, level * parent.height * 0.65)
                    anchors.bottom: parent.bottom
                    color: "white"
                    radius: width / 2
                    opacity: (0.6 + (level * 0.6)) * edgeFactor

                    property real level: (visContainer.processedBars && index < visContainer.processedBars.length) ? visContainer.processedBars[index] : 0.0
                    property real edgeNorm: Math.sin((index / Math.max(1, visContainer.activeBars - 1)) * Math.PI)
                    property real rawEdgeFactor: Math.min(1.0, edgeNorm * 2.0)
                    property real edgeFactor: rawEdgeFactor * rawEdgeFactor * (3.0 - 2.0 * rawEdgeFactor)

                    Behavior on height {
                        NumberAnimation {
                            duration: 75
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 75
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }
        }

        // Image Overlay Component
        Image {
            z: 10
            anchors.fill: parent
            source: "file:///home/vibhu/Pictures/Wallpapers/surreal-cherry-transparent.png"
            fillMode: Image.PreserveAspectCrop
        }
    }
}
