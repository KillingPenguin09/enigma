import QtQuick
import Quickshell
import Quickshell.Io
import "reusables"
import "reusables/inputs"

ShellRoot {
    id: root

    Window {
        id: fileManagerWindow
        width: 960
        height: 640
        color: "transparent"
        visible: true

        onClosing: function(close) {
            Quickshell.exit(0);
        }
        
        EnigmaFiles {
            anchors.fill: parent
            
            places: [
                { name: "Home", path: Quickshell.env("HOME"), icon: "󰋜" },
                { name: "Documents", path: Quickshell.env("HOME") + "/Documents", icon: "󰈙" },
                { name: "Downloads", path: Quickshell.env("HOME") + "/Downloads", icon: "󰇚" },
                { name: "Pictures", path: Quickshell.env("HOME") + "/Pictures", icon: "󰉏" },
                { name: "Videos", path: Quickshell.env("HOME") + "/Videos", icon: "󰕧" },
                { name: "Music", path: Quickshell.env("HOME") + "/Music", icon: "󰝚" },
                { name: "Root", path: "/", icon: "󰋊" }
            ]

            onFileSelected: function(filePath, fileName) {
                console.log("Opening file: " + filePath);
                xdgOpen.command = ["xdg-open", filePath];
                xdgOpen.running = true;
            }
        }
    }

    Process {
        id: xdgOpen
        command: ["xdg-open"]
    }
}
