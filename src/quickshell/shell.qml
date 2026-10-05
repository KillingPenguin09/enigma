import QtQuick
import Quickshell
import Quickshell.Io
import "widgets"
import "overlay"

ShellRoot {
    readonly property bool performanceMode: !!(Config.getSetting("general", {}).performance)
    readonly property bool quickactionsEnabled: Config.getSetting("general", {}).quickactions !== false
    readonly property bool dockEnabled: Config.getSetting("dock", {}).enabled !== false

    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    ScreenshotOverlay {}
    Main {
        id: mainShell
    }
    Bar {}
    Lock {}
    WidgetRedactor {}



    Launcher {}
    Clipboard {}
    Emoji {}

    Polkit {}
    PopoutManager {}

    Loader {
        active: dockEnabled
        sourceComponent: Dock {}
    }

    Loader {
        active: !performanceMode
        sourceComponent: Idle {}
    }
    Variants {
        model: performanceMode ? [] : Quickshell.screens
        delegate: WidgetLoader {
            required property var modelData
            screen: modelData
            monitorName: modelData.name
        }
    }
    Loader {
        active: !performanceMode
        sourceComponent: WallpaperEngine {}
    }
    Loader {
        active: !performanceMode && quickactionsEnabled
        sourceComponent: Floating {}
    }

    IpcHandler {
        target: "clipboardmenu"
        function toggle(): void { ClipboardController.toggle(); }
    }
    IpcHandler {
        target: "switcher"
        function open(): void { mainShell.switchWidget("guide", ""); }
    }
    IpcHandler {
        target: "notifications"
        function toggle(): void { mainShell.switchWidget("notifications", ""); }
    }
    IpcHandler {
        target: "emojimenu"
        function toggle(): void { EmojiController.toggle(); }
    }
    IpcHandler {
        target: "taskwarrior"
        function toggle(): void { mainShell.switchWidget("system", ""); }
    }
    IpcHandler {
        target: "wallpaperpicker"
        function toggle(): void { mainShell.switchWidget("wallpaper", ""); }
    }
    IpcHandler {
        target: "launcher"
        function toggle(): void { LauncherController.toggle(); }
    }
    IpcHandler {
        target: "controlcenter"
        function toggle(): void { mainShell.switchWidget("system", ""); }
    }

    Component.onCompleted: {
        FirstLaunch.checkFirstLaunch();
    }
}
