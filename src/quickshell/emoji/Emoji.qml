import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../"
import "../reusables"

PanelWindow {
    id: emojiWindow

    screen: EmojiController.screen

    WlrLayershell.namespace: "qs-emoji"
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: emojiWindow.isVisible
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    mask: Region { item: topBarHole; intersection: Intersection.Xor }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(val) {
        return (typeof Scaler !== "undefined" && Scaler.s) ? Scaler.s(val) : val;
    }

    function closeEmoji() {
        EmojiController.hide();
    }

    property bool isVisible: EmojiController.isVisible
    property int configRevision: 0
    property bool isDirty: true

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            EmojiController.hide();
            emojiWindow.configRevision++;
        }
    }

    property var rawBarSettings: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) ? Config.rawSettings.bar : ({});
    }
    property string barPosition: (rawBarSettings && rawBarSettings.position !== undefined) ? rawBarSettings.position : "top"
    property bool barAutohide: (rawBarSettings && rawBarSettings.autohide !== undefined) ? Boolean(rawBarSettings.autohide) : false

    readonly property bool isFullscreenActive: {
        try {
            if (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) {
                return Boolean(Hyprland.focusedWorkspace.hasFullscreen || (Hyprland.activeToplevel && Hyprland.activeToplevel.fullscreen));
            }
        } catch (e) {}
        return false;
    }

    readonly property bool isBarEffectivelyHidden: barAutohide || isFullscreenActive

    property string attachEdge: {
        if (barPosition === "bottom") return "top";
        if (barPosition === "left") return "right";
        if (barPosition === "right") return "left";
        return "bottom";
    }

    onBarPositionChanged: {
        EmojiController.hide();
    }

    property bool isSideAttached: attachEdge === "left" || attachEdge === "right"

    property real cornerRadius: ThemeBackend.borderRadius <= 16 ? ThemeBackend.borderRadius * 2 : Math.min(32, 32 - 16 * Math.exp(-(ThemeBackend.borderRadius - 16) / 12))
    property real outerCornerRadius: cornerRadius

    property real baseLauncherWidth: isSideAttached ? Math.round(s(460) / 1.1) : Math.round(s(680) / 1.15)
    property int maxVisibleClips: isSideAttached ? 7 : 6

    property real targetLauncherHeight: {
        let count = Math.min(emojiBoxModel.count, maxVisibleClips);
        if (count <= 0) {
            return s(64);
        }
        let hasPinned = false;
        let hasUnpinned = false;
        for (let i = 0; i < count; i++) {
            let item = emojiBoxModel.get(i);
            if (item) {
                if (item.pinned) hasPinned = true;
                else hasUnpinned = true;
            }
        }
        let sectionCount = (hasPinned ? 1 : 0) + (hasUnpinned ? 1 : 0);
        let sectionH = sectionCount === 2 ? s(48) : (sectionCount === 1 ? s(22) : 0);
        return s(70) + sectionH + (count * s(56));
    }

    property real animatedLauncherHeight: targetLauncherHeight
    Behavior on animatedLauncherHeight {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    visible: isVisible || container.animProgress > 0.001

    property var allFetchedEmojis: []
    property int emojiPageSize: 60
    property int emojiOffset: 0
    property bool hasMoreEmojis: true
    property bool fetchPending: false

    property string expandedEmojiId: ""
    property string expandedEmojiFullText: ""
    property bool isClearingEmojis: false

    property bool isKeyboardNav: false
    property string pendingQuery: ""

    function grabInputFocus() {
        searchInput.forceActiveFocus();
        if (typeof searchInput.forceInputFocus === "function") {
            searchInput.forceInputFocus();
        }
    }

    function toggleExpandCurrent() {
        if (emojiList.currentIndex >= 0 && emojiList.currentItem && typeof emojiList.currentItem.toggleExpand === "function") {
            emojiList.currentItem.toggleExpand();
        }
    }

    ListModel {
        id: emojiBoxModel
    }

    Process {
        id: emojiWatcher
        running: true
        command: ["wl-paste", "--watch", "echo", "1"]
        stdout: SplitParser {
            onRead: (data) => {
                if (emojiWindow.isVisible) {
                    emojiWatchDebounce.restart();
                } else {
                    emojiWindow.isDirty = true;
                }
            }
        }
    }

    Timer {
        id: emojiWatchDebounce
        interval: 150
        repeat: false
        onTriggered: {
            emojiWindow.refreshEmojis();
        }
    }

    Process {
        id: fullTextFetcher
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text;
                emojiWindow.expandedEmojiFullText = (t && t.length > 0) ? t : "";
            }
        }
    }

    function fetchFullText(id) {
        emojiWindow.expandedEmojiFullText = "";
        emojiWindow.expandedEmojiId = id ? id.toString() : "";
        if (emojiWindow.expandedEmojiId !== "") {
            fullTextFetcher.command = ["cliphist", "decode", emojiWindow.expandedEmojiId];
            fullTextFetcher.running = true;
        }
    }

    function isSubsequence(sub, str) {
        let i = 0;
        let j = 0;
        while (i < sub.length && j < str.length) {
            if (sub[i] === str[j]) {
                i++;
            }
            j++;
        }
        return i === sub.length;
    }

    function syncEmojiBoxModel(targetItems) {
        for (let i = 0; i < targetItems.length; i++) {
            let item = targetItems[i];
            if (i < emojiBoxModel.count) {
                let cur = emojiBoxModel.get(i);
                if (cur.id !== item.id || cur.pinned !== item.pinned || cur.content !== item.content || cur.type !== item.type || cur.sectionCategory !== item.sectionCategory || cur.score !== item.score) {
                    emojiBoxModel.set(i, item);
                }
            } else {
                emojiBoxModel.append(item);
            }
        }

        while (emojiBoxModel.count > targetItems.length) {
            emojiBoxModel.remove(emojiBoxModel.count - 1);
        }
    }

    function executeEmojiFilter(query) {
        emojiWindow.isKeyboardNav = false;
        if (keyboardNavTimer.running) keyboardNavTimer.stop();

        let rawTrimmed = (query || "").trim();
        let q = rawTrimmed.toLowerCase();
        let filtered = [];

        let pinnedLabel = typeof I18n !== "undefined" ? I18n.t("emoji.pinned", "Pinned") : "Pinned";
        let recentLabel = typeof I18n !== "undefined" ? I18n.t("emoji.recent", "Recent") : "Recent";

        for (let i = 0; i < emojiWindow.allFetchedEmojis.length; i++) {
            let item = emojiWindow.allFetchedEmojis[i];
            let contentLower = (item.content || "").toLowerCase();
            let matchQuality = 0;
            let matches = false;

            if (q.length === 0) {
                matches = true;
            } else {
                if (contentLower === q) {
                    matchQuality = 100000;
                    matches = true;
                } else if (contentLower.startsWith(q)) {
                    matchQuality = 50000;
                    matches = true;
                } else if (contentLower.includes(q)) {
                    matchQuality = 10000;
                    matches = true;
                } else if (isSubsequence(q, contentLower)) {
                    matchQuality = 1000;
                    matches = true;
                }
            }

            if (matches) {
                filtered.push({
                    id: item.id,
                    pinned: Boolean(item.pinned),
                    content: item.content || "",
                    type: item.type || "text",
                    sectionCategory: item.pinned ? pinnedLabel : recentLabel,
                    score: (item.pinned ? 500000 : 0) + matchQuality
                });
            }
        }

        if (q.length > 0) {
            filtered.sort(function(a, b) {
                if (a.score !== b.score) {
                    return b.score - a.score;
                }
                return 0;
            });
        } else {
            let pinnedItems = [];
            let unpinnedItems = [];
            for (let i = 0; i < filtered.length; i++) {
                if (filtered[i].pinned) pinnedItems.push(filtered[i]);
                else unpinnedItems.push(filtered[i]);
            }
            filtered = pinnedItems.concat(unpinnedItems);
        }

        syncEmojiBoxModel(filtered);

        emojiList.resetScroll();

        if (emojiBoxModel.count > 0) {
            emojiList.currentIndex = 0;
        } else {
            emojiList.currentIndex = -1;
        }
    }

    function filterEmojis(query) {
        emojiWindow.pendingQuery = query;
        filterDebounceTimer.restart();
    }

    Timer {
        id: filterDebounceTimer
        interval: 80
        repeat: false
        onTriggered: {
            emojiWindow.executeEmojiFilter(emojiWindow.pendingQuery);
        }
    }

    Process {
        id: emojiFetcherProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (emojiWindow.fetchPending) {
                    emojiWindow.fetchPending = false;
                    emojiWindow.emojiOffset = 0;
                    emojiWindow.hasMoreEmojis = true;
                    emojiWindow.fetchNextEmojiPage();
                    return;
                }

                try {
                    let txt = this.text.trim();
                    if (txt.length > 0) {
                        let items = JSON.parse(txt);
                        if (items.length < emojiWindow.emojiPageSize) {
                            emojiWindow.hasMoreEmojis = false;
                        }

                        if (emojiWindow.emojiOffset === 0) {
                            emojiWindow.allFetchedEmojis = items;
                        } else {
                            let existingIds = {};
                            for (let i = 0; i < emojiWindow.allFetchedEmojis.length; i++) {
                                existingIds[emojiWindow.allFetchedEmojis[i].id] = true;
                            }
                            for (let i = 0; i < items.length; i++) {
                                if (!existingIds[items[i].id]) {
                                    emojiWindow.allFetchedEmojis.push(items[i]);
                                    existingIds[items[i].id] = true;
                                }
                            }
                        }
                        emojiWindow.emojiOffset = emojiWindow.allFetchedEmojis.length;
                        emojiWindow.executeEmojiFilter(searchInput.text);
                    } else {
                        emojiWindow.hasMoreEmojis = false;
                        if (emojiWindow.emojiOffset === 0) {
                            emojiWindow.allFetchedEmojis = [];
                            emojiWindow.executeEmojiFilter(searchInput.text);
                        }
                    }
                } catch(e) {
                    emojiWindow.hasMoreEmojis = false;
                }
            }
        }
    }

    Process {
        id: emojiActionProc
        running: false
    }

    function refreshEmojis() {
        emojiWindow.emojiOffset = 0;
        emojiWindow.hasMoreEmojis = true;
        if (emojiFetcherProc.running) {
            emojiWindow.fetchPending = true;
            return;
        }
        fetchNextEmojiPage();
    }

    function fetchNextEmojiPage() {
        if (emojiFetcherProc.running || !emojiWindow.hasMoreEmojis) return;
        let qsDir = (typeof Caching !== "undefined" && Caching.qsDir) ? Caching.qsDir : "";
        let cacheDir = (typeof Caching !== "undefined" && Caching.getCacheDir) ? Caching.getCacheDir("emoji") : "";
        emojiFetcherProc.command = ["python3", qsDir + "/emoji/emoji_fetcher.py", emojiWindow.emojiOffset.toString(), emojiWindow.emojiPageSize.toString(), cacheDir];
        emojiFetcherProc.running = true;
    }

    function copyEmoji(id, isPinned) {
        if (typeof Sounds !== "undefined") Sounds.playSfx("system/quick_click.wav");
        let emoji = "";
        for (let i=0; i<emojiWindow.allFetchedEmojis.length; i++) {
            if (emojiWindow.allFetchedEmojis[i].id.toString() === id.toString()) {
                emoji = emojiWindow.allFetchedEmojis[i].emojiChar;
                break;
            }
        }
        if (emoji) {
            Quickshell.execDetached(["bash", "-c", "echo -n '" + emoji + "' | wl-copy"]);
        }
        closeEmoji();
    }

    function pinEmoji(id, index) {
        emojiActionProc.command = ["python3", Caching.qsDir + "/emoji/emoji_fetcher.py", "pin", id.toString(), Caching.getCacheDir("emoji")];
        emojiActionProc.running = true;
        for (let i = 0; i < emojiWindow.allFetchedEmojis.length; i++) {
            if (emojiWindow.allFetchedEmojis[i].id.toString() === id.toString()) {
                emojiWindow.allFetchedEmojis[i].pinned = !emojiWindow.allFetchedEmojis[i].pinned;
                break;
            }
        }
        emojiWindow.executeEmojiFilter(searchInput.text);
    }

    function deleteEmoji(id, index) {
        emojiActionProc.command = ["python3", Caching.qsDir + "/emoji/emoji_fetcher.py", "delete", id.toString(), Caching.getCacheDir("emoji")];
        emojiActionProc.running = true;
        emojiWindow.allFetchedEmojis = emojiWindow.allFetchedEmojis.filter(item => item.id.toString() !== id.toString());
        emojiBoxModel.remove(index);
    }

    function clearAllEmojis() {
        emojiWindow.allFetchedEmojis = [];
        emojiBoxModel.clear();
        emojiList.resetScroll();
        emojiActionProc.command = ["python3", Caching.qsDir + "/emoji/emoji_fetcher.py", "wipe", Caching.getCacheDir("emoji")];
        emojiActionProc.running = true;
    }

    Timer {
        id: clearFinishTimer
        interval: 300
        repeat: false
        onTriggered: {
            emojiWindow.clearAllEmojis();
            emojiWindow.isClearingEmojis = false;
        }
    }

    function animateClear() {
        if (emojiWindow.isClearingEmojis || emojiBoxModel.count === 0) return;
        emojiWindow.isClearingEmojis = true;

        let visibleDelegates = [];
        for (let i = 0; i < emojiList.contentItem.children.length; i++) {
            let child = emojiList.contentItem.children[i];
            if (child && typeof child.triggerClearSlide === "function") {
                if (child.y + child.height >= emojiList.contentY && child.y <= emojiList.contentY + emojiList.height) {
                    visibleDelegates.push(child);
                }
            }
        }

        visibleDelegates.sort((a, b) => a.y - b.y);

        if (visibleDelegates.length === 0) {
            emojiWindow.clearAllEmojis();
            emojiWindow.isClearingEmojis = false;
            return;
        }

        let step = 50;
        let totalTime = 0;
        for (let i = 0; i < visibleDelegates.length; i++) {
            let d = i * step;
            visibleDelegates[i].triggerClearSlide(d);
            totalTime = d + 220;
        }

        clearFinishTimer.interval = totalTime + 40;
        clearFinishTimer.start();
    }

    function activateIndex(index) {
        if (index < 0 || index >= emojiBoxModel.count) return;
        let item = emojiBoxModel.get(index);
        if (!item) return;
        copyEmoji(item.id, item.pinned);
    }

    Item {
        id: topBarHole

        property int barThickness: 48
        property string bp: emojiWindow.barPosition
        property bool activeBar: !emojiWindow.isBarEffectivelyHidden

        x: {
            if (!activeBar) return 0;
            if (bp === "left") return 0;
            if (bp === "right") return emojiWindow.width - barThickness;
            return 0;
        }

        y: {
            if (!activeBar) return 0;
            if (bp === "top") return 0;
            if (bp === "bottom") return emojiWindow.height - barThickness;
            return 0;
        }

        width: {
            if (!activeBar) return 0;
            if (bp === "left" || bp === "right") return barThickness;
            return emojiWindow.width;
        }

        height: {
            if (!activeBar) return 0;
            if (bp === "top" || bp === "bottom") return barThickness;
            return emojiWindow.height;
        }
    }

    Timer {
        id: focusTimer
        interval: 30
        repeat: false
        onTriggered: {
            emojiWindow.grabInputFocus();
        }
    }

    Timer {
        id: focusRetryTimer
        interval: 120
        repeat: false
        onTriggered: {
            emojiWindow.grabInputFocus();
        }
    }

    Timer {
        id: focusFinalTimer
        interval: 250
        repeat: false
        onTriggered: {
            emojiWindow.grabInputFocus();
        }
    }

    Timer {
        id: keyboardNavTimer
        interval: 500
        repeat: false
        onTriggered: {
            emojiWindow.isKeyboardNav = false;
        }
    }

    onIsVisibleChanged: {
        if (isVisible) {
            searchInput.clear();
            filterDebounceTimer.stop();
            if (emojiWindow.isDirty || emojiWindow.allFetchedEmojis.length === 0) {
                emojiWindow.isDirty = false;
                refreshEmojis();
            } else {
                executeEmojiFilter("");
            }
            emojiWindow.grabInputFocus();
            focusTimer.restart();
            focusRetryTimer.restart();
            focusFinalTimer.restart();
        } else {
            emojiList.resetScroll();
            emojiWindow.expandedEmojiId = "";
            filterDebounceTimer.stop();
            focusTimer.stop();
            focusRetryTimer.stop();
            focusFinalTimer.stop();
            keyboardNavTimer.stop();
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: emojiWindow.isVisible
        onClicked: closeEmoji()
    }

    Item {
        id: container

        MouseArea {
            anchors.fill: parent
        }

        property real animProgress: emojiWindow.isVisible ? 1.0 : 0.0
        Behavior on animProgress {
            NumberAnimation {
                duration: emojiWindow.isVisible ? 300 : 200
                easing.type: Easing.OutCubic
            }
        }

        property real dynamicCornerRadius: Math.max(0, Math.min(emojiWindow.outerCornerRadius, (emojiWindow.isSideAttached ? width : height)))

        x: {
            if (emojiWindow.attachEdge === "left") return 0;
            if (emojiWindow.attachEdge === "right") return emojiWindow.width - width;
            return Math.floor((emojiWindow.width - width) / 2);
        }
        y: {
            if (emojiWindow.attachEdge === "top") return 0;
            if (emojiWindow.attachEdge === "bottom") return emojiWindow.height - height;
            return Math.floor((emojiWindow.height - height) / 2);
        }
        width: emojiWindow.isSideAttached
               ? (emojiWindow.baseLauncherWidth * animProgress)
               : emojiWindow.baseLauncherWidth
        height: !emojiWindow.isSideAttached
                ? (emojiWindow.animatedLauncherHeight * animProgress)
                : emojiWindow.animatedLauncherHeight

        opacity: (emojiWindow.isVisible || animProgress > 0.001) ? 1.0 : 0.0

        Shape {
            visible: emojiWindow.attachEdge === "top" && container.dynamicCornerRadius > 0.5
            x: -container.dynamicCornerRadius
            y: 0
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: 0
                startY: 0
                PathLine { x: container.dynamicCornerRadius; y: 0 }
                PathLine { x: container.dynamicCornerRadius; y: container.dynamicCornerRadius }
                PathArc {
                    x: 0
                    y: 0
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }

        Shape {
            visible: emojiWindow.attachEdge === "top" && container.dynamicCornerRadius > 0.5
            x: parent.width
            y: 0
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: container.dynamicCornerRadius
                startY: 0
                PathLine { x: 0; y: 0 }
                PathLine { x: 0; y: container.dynamicCornerRadius }
                PathArc {
                    x: container.dynamicCornerRadius
                    y: 0
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Clockwise
                }
            }
        }

        Shape {
            visible: emojiWindow.attachEdge === "bottom" && container.dynamicCornerRadius > 0.5
            x: -container.dynamicCornerRadius
            y: parent.height - container.dynamicCornerRadius
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: 0
                startY: container.dynamicCornerRadius
                PathLine { x: container.dynamicCornerRadius; y: container.dynamicCornerRadius }
                PathLine { x: container.dynamicCornerRadius; y: 0 }
                PathArc {
                    x: 0
                    y: container.dynamicCornerRadius
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Clockwise
                }
            }
        }

        Shape {
            visible: emojiWindow.attachEdge === "bottom" && container.dynamicCornerRadius > 0.5
            x: parent.width
            y: parent.height - container.dynamicCornerRadius
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: container.dynamicCornerRadius
                startY: container.dynamicCornerRadius
                PathLine { x: 0; y: container.dynamicCornerRadius }
                PathLine { x: 0; y: 0 }
                PathArc {
                    x: container.dynamicCornerRadius
                    y: container.dynamicCornerRadius
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }

        Shape {
            visible: emojiWindow.attachEdge === "left" && container.dynamicCornerRadius > 0.5
            x: 0
            y: -container.dynamicCornerRadius
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: 0
                startY: 0
                PathLine { x: 0; y: container.dynamicCornerRadius }
                PathLine { x: container.dynamicCornerRadius; y: container.dynamicCornerRadius }
                PathArc {
                    x: 0
                    y: 0
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Clockwise
                }
            }
        }

        Shape {
            visible: emojiWindow.attachEdge === "left" && container.dynamicCornerRadius > 0.5
            x: 0
            y: parent.height
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: 0
                startY: container.dynamicCornerRadius
                PathLine { x: 0; y: 0 }
                PathLine { x: container.dynamicCornerRadius; y: 0 }
                PathArc {
                    x: 0
                    y: container.dynamicCornerRadius
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }

        Shape {
            visible: emojiWindow.attachEdge === "right" && container.dynamicCornerRadius > 0.5
            x: parent.width - container.dynamicCornerRadius
            y: -container.dynamicCornerRadius
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: container.dynamicCornerRadius
                startY: 0
                PathLine { x: container.dynamicCornerRadius; y: container.dynamicCornerRadius }
                PathLine { x: 0; y: container.dynamicCornerRadius }
                PathArc {
                    x: container.dynamicCornerRadius
                    y: 0
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Counterclockwise
                }
            }
        }

        Shape {
            visible: emojiWindow.attachEdge === "right" && container.dynamicCornerRadius > 0.5
            x: parent.width - container.dynamicCornerRadius
            y: parent.height
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: ThemeBackend.base
                strokeColor: "transparent"
                startX: container.dynamicCornerRadius
                startY: container.dynamicCornerRadius
                PathLine { x: container.dynamicCornerRadius; y: 0 }
                PathLine { x: 0; y: 0 }
                PathArc {
                    x: container.dynamicCornerRadius
                    y: container.dynamicCornerRadius
                    radiusX: container.dynamicCornerRadius
                    radiusY: container.dynamicCornerRadius
                    direction: PathArc.Clockwise
                }
            }
        }

        Rectangle {
            id: bgCard
            anchors.fill: parent
            radius: emojiWindow.cornerRadius
            color: ThemeBackend.base
            border.width: 0
            border.color: "transparent"
            clip: true

            Rectangle {
                visible: emojiWindow.attachEdge === "top" && container.dynamicCornerRadius > 0.5
                x: 0
                y: 0
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: emojiWindow.attachEdge === "top" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius
                y: 0
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: emojiWindow.attachEdge === "bottom" && container.dynamicCornerRadius > 0.5
                x: 0
                y: parent.height - container.dynamicCornerRadius
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: emojiWindow.attachEdge === "bottom" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius
                y: parent.height - container.dynamicCornerRadius
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: emojiWindow.attachEdge === "left" && container.dynamicCornerRadius > 0.5
                x: 0
                y: 0
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: emojiWindow.attachEdge === "left" && container.dynamicCornerRadius > 0.5
                x: 0
                y: parent.height - container.dynamicCornerRadius
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: emojiWindow.attachEdge === "right" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius
                y: 0
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Rectangle {
                visible: emojiWindow.attachEdge === "right" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius
                y: parent.height - container.dynamicCornerRadius
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: ThemeBackend.base
            }

            Item {
                id: contentContainer
                anchors.fill: parent
                anchors.margins: emojiWindow.s(14)

                readonly property bool isSearchAtBottom: emojiWindow.attachEdge === "bottom"

                RowLayout {
                    id: searchRow
                    z: 10
                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: contentContainer.isSearchAtBottom ? (parent.height - height) : 0
                    height: emojiWindow.s(36)
                    spacing: emojiWindow.s(8)

                    Input {
                        id: searchInput
                        focus: true
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredHeight: emojiWindow.s(36)

                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: Math.min(ThemeBackend.borderRadius, emojiWindow.s(10))
                        fontPixelSize: emojiWindow.s(12)
                        charSpacing: 1

                        placeholderText: typeof I18n !== "undefined" ? I18n.t("emoji.search", "Search emoji") : "Search emoji"
                        showClearButton: true

                        onTextEdited: function(newText) {
                            filterEmojis(newText);
                        }
                        onCleared: filterEmojis("")

                        Keys.onDownPressed: function(event) {
                            emojiWindow.isKeyboardNav = true;
                            keyboardNavTimer.restart();
                            if (emojiList.currentIndex < emojiBoxModel.count - 1) {
                                emojiList.currentIndex++;
                            }
                            event.accepted = true;
                        }
                        Keys.onUpPressed: function(event) {
                            emojiWindow.isKeyboardNav = true;
                            keyboardNavTimer.restart();
                            if (emojiList.currentIndex > 0) {
                                emojiList.currentIndex--;
                            }
                            event.accepted = true;
                        }
                        Keys.onTabPressed: function(event) {
                            emojiWindow.toggleExpandCurrent();
                            event.accepted = true;
                        }
                        Keys.onBacktabPressed: function(event) {
                            emojiWindow.toggleExpandCurrent();
                            event.accepted = true;
                        }
                        Keys.onReturnPressed: function(event) {
                            activateIndex(emojiList.currentIndex);
                            event.accepted = true;
                        }
                        Keys.onDeletePressed: function(event) {
                            if (emojiList.currentIndex >= 0 && emojiList.currentIndex < emojiBoxModel.count) {
                                let item = emojiBoxModel.get(emojiList.currentIndex);
                                if (item) {
                                    deleteEmoji(item.id, emojiList.currentIndex);
                                }
                            }
                            event.accepted = true;
                        }
                        Keys.onEscapePressed: function(event) {
                            closeEmoji();
                            event.accepted = true;
                        }
                    }

                    ClickButton {
                        id: clearBtn
                        enabled: !emojiWindow.isClearingEmojis && emojiBoxModel.count > 0
                        Layout.preferredWidth: emojiWindow.s(80)
                        Layout.preferredHeight: emojiWindow.s(36)
                        horizontalPadding: emojiWindow.s(10)
                        cornerRadius: Math.min(ThemeBackend.borderRadius, emojiWindow.s(10))
                        buttonText: typeof I18n !== "undefined" ? (I18n.t("emoji.clear") || "Clear") : "Clear"
                        textFontSize: emojiWindow.s(11)
                        buttonIcon: "󰆴"
                        iconFontSize: emojiWindow.s(14)
                        accentColor: ThemeBackend.surface0
                        textColor: ThemeBackend.text
                        visible: true

                        onTriggered: {
                            emojiWindow.animateClear();
                        }
                    }
                }

                Item {
                    id: listContainer
                    z: 1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: contentContainer.isSearchAtBottom ? 0 : (searchRow.height + emojiWindow.s(10))
                    height: Math.max(0, parent.height - searchRow.height - emojiWindow.s(10))
                    clip: true

                    NumberAnimation {
                        id: scrollAnim
                        target: emojiList
                        property: "contentY"
                        duration: 260
                        easing.type: Easing.OutCubic
                    }

                    GridView {
                        id: emojiList
                        anchors.fill: parent
                        clip: true
                        model: emojiBoxModel
                        cellWidth: emojiWindow.s(52)
                        cellHeight: emojiWindow.s(52)
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds
                        cacheBuffer: emojiWindow.s(600)
                        interactive: !emojiWindow.isClearingEmojis && (contentHeight > height)

                        highlightFollowsCurrentItem: false

                        function resetScroll() {
                            scrollAnim.stop();
                            positionViewAtBeginning();
                            contentY = 0;
                        }

                        function ensureVisible(idx, animated) {
                            if (idx < 0 || emojiBoxModel.count === 0) return;
                            let row = Math.floor(idx / Math.max(1, Math.floor(width / cellWidth)));
                            let itemTop = row * cellHeight;
                            let itemBottom = itemTop + cellHeight;

                            let curContentY = scrollAnim.running ? scrollAnim.to : contentY;
                            let maxScroll = Math.max(0, contentHeight - height);
                            let newContentY = curContentY;

                            if (itemTop < curContentY) {
                                newContentY = itemTop;
                            } else if (itemBottom > curContentY + height) {
                                newContentY = itemBottom - height;
                            }

                            newContentY = Math.max(0, Math.min(maxScroll, newContentY));

                            if (Math.abs(newContentY - contentY) > 0.5) {
                                if (animated) {
                                    scrollAnim.stop();
                                    scrollAnim.from = contentY;
                                    scrollAnim.to = newContentY;
                                    scrollAnim.start();
                                } else {
                                    scrollAnim.stop();
                                    contentY = newContentY;
                                }
                            }
                        }

                        onMovementStarted: {
                            scrollAnim.stop();
                        }

                        onCurrentIndexChanged: {
                            if (currentIndex >= 0) {
                                ensureVisible(currentIndex, emojiWindow.isKeyboardNav);
                            }
                        }

                        add: Transition {
                            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 250; easing.type: Easing.OutCubic }
                            NumberAnimation { property: "scale"; from: 0.96; to: 1.0; duration: 270; easing.type: Easing.OutCubic }
                        }

                        remove: Transition {
                            NumberAnimation { property: "opacity"; to: 0.0; duration: 170; easing.type: Easing.OutCubic }
                            NumberAnimation { property: "scale"; to: 0.96; duration: 170; easing.type: Easing.OutCubic }
                        }

                        displaced: null

                        onContentYChanged: {
                            if (contentY < 0 && !moving && !flicking) {
                                contentY = 0;
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            active: emojiList.moving || emojiList.movingVertically
                            width: emojiWindow.s(4)
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle { implicitWidth: emojiWindow.s(4); radius: emojiWindow.s(2); color: ThemeBackend.surface2 }
                        }

                        delegate: Item {
                            id: emojiDelegateWrapper
                            width: emojiList.cellWidth
                            height: emojiList.cellHeight
                            z: isSelected ? 2 : 1

                            property bool isSelected: index === emojiList.currentIndex
                            property string emojiIdString: (typeof model !== "undefined" && model && model.id !== undefined) ? model.id.toString() : (emojiBoxModel.get(index) ? emojiBoxModel.get(index).id.toString() : "")

                            scale: emojiCardMa.pressed ? 0.85 : 1.0
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

                            Rectangle {
                                id: emojiDelegateCard
                                anchors.fill: parent
                                anchors.margins: emojiWindow.s(2)
                                radius: emojiWindow.s(12)
                                color: {
                                    if (emojiDelegateWrapper.isSelected) {
                                        return ThemeBackend.mauve;
                                    }
                                    return emojiCardMa.containsMouse ? Qt.lighter(ThemeBackend.surface1, 1.04) : "transparent";
                                }
                                Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: model.emojiChar || (model.content ? model.content.split(' ')[0] : "")
                                    font.pixelSize: emojiWindow.s(24)
                                }

                                MouseArea {
                                    id: emojiCardMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !emojiWindow.isClearingEmojis
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton
                                    onClicked: {
                                        emojiList.currentIndex = index;
                                        emojiWindow.copyEmoji(emojiDelegateWrapper.emojiIdString, false);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
