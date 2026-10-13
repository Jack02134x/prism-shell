pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.services
import qs.widgets

// Spotlight-style launcher with prefix modes:
//   (none) apps + commands + inline maths    /  commands     @  windows
//   >  clipboard    :  emoji    $  shell    #  web    =  or "c "  calculator
//   y  YouTube      a  anime (ani-cli)      w  wallpapers    ?  help
Overlay {
    id: win

    name: "launcher"
    open: Panels.launcher
    scrimOpacity: 0.4
    onDismiss: Panels.launcher = false
    onOpened: {
        field.text = Panels.launcherQuery;
        field.focusInput();
        list.currentIndex = 0;
        if (win.mode === "clipboard")
            Clipboard.refresh();
    }

    property string query: field.text

    readonly property var modes: [
        { p: "/", mode: "actions", name: "Commands", glyph: "console_line", hint: "Run a shell command palette entry", accent: 2 },
        { p: "@", mode: "windows", name: "Windows", glyph: "dock_window", hint: "Jump to an open window", accent: 5 },
        { p: ">", mode: "clipboard", name: "Clipboard", glyph: "clipboard_text_outline", hint: "Clipboard history (Shift+Del removes)", accent: 3 },
        { p: ":", mode: "emoji", name: "Emoji", glyph: "emoticon_happy_outline", hint: "Pick an emoji to copy", accent: 1 },
        { p: "$", mode: "command", name: "Shell", glyph: "console", hint: "Run a command · ↑↓ history · Shift+Enter in terminal", accent: 6 },
        { p: "#", mode: "web", name: "Web", glyph: "web", hint: "Search the web or open a site · visited sites below", accent: 4 },
        { p: "=", mode: "calc", name: "Calculator", glyph: "calculator", hint: "Maths — Enter copies the result", accent: 8 },
        { p: "c ", mode: "calc", name: "Calculator", glyph: "calculator", hint: "Maths — Enter copies the result", accent: 8 },
        { p: "y ", mode: "youtube", name: "YouTube", glyph: "youtube", hint: "Search YouTube", accent: 0 },
        { p: "a ", mode: "anime", name: "Anime", glyph: "television_play", hint: "Watch with ani-cli", accent: 7 },
        { p: "w ", mode: "wallpaper", name: "Wallpapers", glyph: "palette", hint: "Open the wallpaper picker", accent: 9 },
        { p: "?", mode: "help", name: "Help", glyph: "help_circle_outline", hint: "All prefixes", accent: 2 }
    ]
    readonly property var appsMode: ({ p: "", mode: "apps", name: "Apps", glyph: "apps", hint: "Search apps, commands, or type maths", accent: 0 })
    readonly property var current: modes.find(m => query.toLowerCase().startsWith(m.p)) ?? appsMode
    readonly property string mode: current.mode
    readonly property string term: query.slice(current.p.length).trim()
    readonly property color accent: Theme.accent(current.accent)

    onModeChanged: {
        if (mode === "clipboard")
            Clipboard.refresh();
        if (mode === "wallpaper" && open)
            Qt.callLater(() => Panels.openWallpapers(win.term));
        list.currentIndex = 0;
        emojiGrid.currentIndex = 0;
    }
    onTermChanged: {
        list.currentIndex = 0;
        emojiGrid.currentIndex = 0;
    }

    function run(r, mods) {
        if (!r)
            return;
        const keep = r.keepOpen === true;
        if (!keep)
            Panels.launcher = false;
        if (mods && (mods & Qt.ShiftModifier) && r.alt)
            r.alt();
        else
            r.run();
    }

    function webUrl(s) {
        if (/^https?:\/\//i.test(s))
            return s;
        if (/^[^\s/]+\.[^\s]{2,}(\/\S*)?$/.test(s))
            return "https://" + s;
        return Config.apps.searchUrl + encodeURIComponent(s);
    }

    readonly property var results: {
        const q = term;
        const hl = Theme.accent(current.accent).toString();
        switch (mode) {
        case "apps":
            {
                const out = [];
                if (Calc.looksLikeMath(q)) {
                    const c = Calc.evaluate(q);
                    if (c.ok)
                        out.push({ title: "= " + c.text, sub: "Enter to copy", glyph: "calculator", accent: 8, run: () => Quickshell.execDetached(["wl-copy", String(c.value)]) });
                }
                for (const e of Apps.search(q))
                    out.push({ title: Apps.highlight(e.name, q.toLowerCase(), hl), sub: e.genericName || e.comment || "", iconUrl: Quickshell.iconPath(e.icon, true), glyph: "application", accent: 0, entry: e, run: () => Apps.launch(e) });
                // apps only (commands live under "/")
                return out;
            }
        case "actions":
            return Actions.list.map(a => ({ a, s: q === "" ? 1 : Math.max(Apps.score(a.name, q.toLowerCase()), Apps.score(a.kw + " " + a.desc, q.toLowerCase()) * 0.6) })).filter(x => x.s > 0).sort((x, y) => y.s - x.s).map((x, i) => ({ title: Apps.highlight(x.a.name, q.toLowerCase(), hl), sub: x.a.desc, glyph: x.a.icon, accent: i, run: x.a.run }));
        case "windows":
            return Hypr.realToplevels.filter(t => (t.title + " " + Hypr.classOf(t)).toLowerCase().includes(q.toLowerCase())).map(t => ({ title: Utils.escapeHtml(t.title), sub: Hypr.appName(Hypr.classOf(t)) + " · " + (t.workspace?.name ?? "?"), iconUrl: Hypr.iconFor(Hypr.classOf(t)), glyph: "application", accent: 5, run: () => Hypr.activate(t) }));
        case "clipboard":
            return Clipboard.entries.filter(e => q === "" || e.text.toLowerCase().includes(q.toLowerCase())).slice(0, 120).map(e => ({ title: e.image ? "Image" : Utils.escapeHtml(e.text.slice(0, 200)), sub: e.image ? e.text.replace(/^\[\[ binary data /, "").replace(/ \]\]$/, "") : "#" + e.id, image: e.image ? Clipboard.preview(e) : "", glyph: e.image ? "image" : "content_paste", accent: 3, clip: e, run: () => Clipboard.copy(e), del: () => Clipboard.remove(e) }));
        case "command":
            {
                const runCmd = c => {
                    History.addCommand(c);
                    Quickshell.execDetached(["sh", "-c", c]);
                };
                const runTerm = c => {
                    History.addCommand(c);
                    Quickshell.execDetached([Config.apps.terminal, "--hold", "sh", "-c", c]);
                };
                const out = q === "" ? [] : [{ title: "Run  <b>" + Utils.escapeHtml(q) + "</b>", sub: "Shift+Enter to run in " + Config.apps.terminal, glyph: "console", accent: 6, run: () => runCmd(q), alt: () => runTerm(q) }];
                // history, newest first; arrow keys walk through it like a shell
                for (const c of History.commands.filter(c => c !== q && (q === "" || c.toLowerCase().includes(q.toLowerCase()))).slice(0, 80))
                    out.push({ title: Apps.highlight(c, q.toLowerCase(), hl), sub: "history · Shift+Enter in terminal", glyph: "history", accent: 7, run: () => runCmd(c), alt: () => runTerm(c), del: () => History.removeCommand(c) });
                return out;
            }
        case "web":
            {
                const open = s => {
                    History.addWeb(s); // only kept when it looks like a site/URL
                    Quickshell.execDetached([Config.apps.browser, webUrl(s)]);
                };
                const out = q === "" ? [] : [{ title: (History.isSite(q) ? "Open  " : "Search  ") + "<b>" + Utils.escapeHtml(q) + "</b>", sub: webUrl(q), glyph: "web", accent: 4, run: () => open(q) }];
                for (const w of History.web.filter(w => w !== q && (q === "" || w.toLowerCase().includes(q.toLowerCase()))).slice(0, 60))
                    out.push({ title: Apps.highlight(w, q.toLowerCase(), hl), sub: "visited", glyph: "history", accent: 5, run: () => open(w), del: () => History.removeWeb(w) });
                return out;
            }
        case "youtube":
            return q === "" ? [] : [{ title: "YouTube  <b>" + Utils.escapeHtml(q) + "</b>", sub: "Search in " + Config.apps.browser, glyph: "youtube", accent: 0, run: () => Quickshell.execDetached([Config.apps.browser, "https://www.youtube.com/results?search_query=" + encodeURIComponent(q)]) }];
        case "anime":
            return q === "" ? [] : [{ title: "Watch  <b>" + Utils.escapeHtml(q) + "</b>", sub: "ani-cli in " + Config.apps.terminal, glyph: "television_play", accent: 7, run: () => Quickshell.execDetached([Config.apps.terminal, "-e", "ani-cli", q]) }, { title: "Download  <b>" + Utils.escapeHtml(q) + "</b>", sub: "ani-cli -d into ~/Videos/anime", glyph: "download", accent: 8, run: () => Quickshell.execDetached({ command: [Config.apps.terminal, "-e", "ani-cli", "-d", q], workingDirectory: Config.home + "/Videos/anime" }) }];
        case "help":
            return modes.filter((m, i) => modes.findIndex(n => n.mode === m.mode) === i).map(m => ({ title: "<b>" + Utils.escapeHtml(m.p.trim()) + "</b>   " + m.name, sub: m.hint, glyph: m.glyph, accent: m.accent, keepOpen: true, run: () => {
                            field.text = m.p;
                        } }));
        default:
            return [];
        }
    }

    readonly property var calc: mode === "calc" ? Calc.evaluate(term) : null
    readonly property var emojis: mode === "emoji" ? Emojis.search(term) : []
    readonly property bool gridMode: mode === "emoji"

    Rectangle {
        id: card
        width: Math.min(760, parent.width - 40)
        height: Math.min(parent.height * 0.72, header.height + body.implicitHeight + footer.height + 24)
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.13 + (1 - win.progress) * -30
        radius: Theme.r.xl
        gradient: TintGradient { alpha: 0.95; amount: 0.16 }
        border.width: 1
        border.color: Theme.alpha(win.accent, 0.35)
        opacity: win.progress
        scale: 0.94 + 0.06 * win.progress
        clip: false

        Behavior on height { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatial } }
        Behavior on border.color { ColAnim {} }

        GlowBorder {
            z: -1
            radius: card.radius
            pad: 18
            thickness: 2
            glow: 0.55
            speed: 3
            c1: win.accent
        }

        MouseArea {
            anchors.fill: parent
        }

        // ---------- header ----------
        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 84

            ClippingRectangle {
                anchors.fill: parent
                anchors.margins: 1
                topLeftRadius: card.radius
                topRightRadius: card.radius
                color: "transparent"
                Aurora {
                    anchors.fill: parent
                    intensity: 0.75
                    c1: win.accent
                    bg: Theme.alpha(Theme.surfaceLow, 0.0)
                    opacity: 0.55
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                // mode chip
                Rectangle {
                    Layout.preferredHeight: 46
                    Layout.preferredWidth: chipRow.implicitWidth + 26
                    radius: 15
                    color: win.accent
                    Behavior on Layout.preferredWidth { NumAnim { duration: Motion.normal; easing.bezierCurve: Motion.spatial } }
                    Behavior on color { ColAnim {} }
                    RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 8
                        Icon {
                            icon: win.current.glyph
                            size: 18
                            color: Theme.on(win.accent)
                        }
                        Txt {
                            text: win.current.name
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            color: Theme.on(win.accent)
                        }
                    }
                }

                InputField {
                    id: field
                    Layout.fillWidth: true
                    icon: ""
                    accent: win.accent
                    fontSize: 17
                    placeholder: win.current.hint
                    horizontalNav: win.gridMode
                    onNavigate: (delta, vertical) => {
                        if (win.gridMode) {
                            const cols = Math.max(1, Math.floor(emojiGrid.width / emojiGrid.cellWidth));
                            emojiGrid.currentIndex = Utils.clamp(emojiGrid.currentIndex + (vertical ? delta * cols : delta), 0, Math.max(0, emojiGrid.count - 1));
                        } else {
                            list.currentIndex = Utils.clamp(list.currentIndex + delta, 0, Math.max(0, list.count - 1));
                        }
                    }
                    onSubmitted: mods => {
                        if (win.gridMode) {
                            const e = win.emojis[emojiGrid.currentIndex];
                            if (e) {
                                Emojis.pick(e);
                                Panels.launcher = false;
                            }
                        } else if (win.mode === "calc") {
                            if (win.calc?.ok) {
                                Quickshell.execDetached(["wl-copy", String(win.calc.value)]);
                                Panels.launcher = false;
                            }
                        } else {
                            win.run(win.results[list.currentIndex], mods);
                        }
                    }
                    onDeleteRequested: {
                        const r = win.results[list.currentIndex];
                        if (r?.del)
                            r.del();
                    }
                }
            }
        }

        // ---------- body ----------
        Item {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: header.bottom
            anchors.bottom: footer.top
            anchors.margins: 12
            anchors.topMargin: 4
            implicitHeight: win.gridMode ? 360 : win.mode === "calc" ? 150 : Math.min(470, Math.max(list.contentHeight, 90))

            // calculator display
            Item {
                anchors.fill: parent
                visible: win.mode === "calc"
                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.term || "2 ^ 10 + sqrt(16)"
                        font.family: Theme.mono
                        font.pixelSize: 15
                        color: Theme.fgDim
                    }
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.calc?.ok ? "= " + win.calc.text : (win.calc?.text ?? "")
                        font.family: Theme.display
                        font.pixelSize: 46
                        font.weight: Font.Black
                        color: win.calc?.ok ? Theme.accent(8) : Theme.fgDim
                    }
                }
            }

            // emoji grid
            GridView {
                id: emojiGrid
                anchors.fill: parent
                visible: win.gridMode
                clip: true
                cellWidth: Math.floor(width / 12)
                cellHeight: 58
                model: win.emojis
                highlightMoveDuration: 120
                highlight: Rectangle {
                    radius: 14
                    color: Theme.alpha(win.accent, 0.3)
                    border.width: 2
                    border.color: win.accent
                }
                delegate: Item {
                    id: emo
                    required property var modelData
                    required property int index
                    width: emojiGrid.cellWidth
                    height: emojiGrid.cellHeight
                    Text {
                        anchors.centerIn: parent
                        text: emo.modelData.ch
                        font.family: "Noto Color Emoji"
                        font.pixelSize: emoHover.hovered ? 34 : 28
                        Behavior on font.pixelSize { NumAnim { duration: Motion.fast; easing.bezierCurve: Motion.spatialFast } }
                    }
                    HoverHandler {
                        id: emoHover
                        onHoveredChanged: if (hovered) emojiGrid.currentIndex = emo.index
                    }
                    TapHandler {
                        onTapped: {
                            Emojis.pick(emo.modelData);
                            Panels.launcher = false;
                        }
                    }
                }
            }

            // results list
            ListView {
                id: list
                anchors.fill: parent
                visible: !win.gridMode && win.mode !== "calc"
                clip: true
                spacing: 4
                model: win.results
                highlightMoveDuration: 160
                highlightResizeDuration: 0
                boundsBehavior: Flickable.StopAtBounds
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                highlight: Rectangle {
                    radius: 16
                    color: Theme.alpha(win.accent, 0.16)
                    border.width: 1
                    border.color: Theme.alpha(win.accent, 0.6)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 4
                        width: 4
                        height: parent.height * 0.5
                        radius: 2
                        color: win.accent
                    }
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool selected: ListView.isCurrentItem
                    readonly property color rowAccent: Theme.accent(modelData.accent ?? 0)
                    width: list.width
                    height: modelData.image ? 84 : 58

                    opacity: 0
                    transform: Translate { id: rowT; x: 24 }
                    Component.onCompleted: rowIn.start()
                    SequentialAnimation {
                        id: rowIn
                        PauseAnimation { duration: Math.min(row.index, 10) * 22 }
                        ParallelAnimation {
                            NumberAnimation { target: row; property: "opacity"; to: 1; duration: Motion.normal }
                            NumberAnimation { target: rowT; property: "x"; to: 0; duration: Motion.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatial }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 14
                        spacing: 14

                        // icon
                        Item {
                            Layout.preferredWidth: row.modelData.image ? 96 : 36
                            Layout.preferredHeight: row.modelData.image ? 66 : 36
                            Rectangle {
                                anchors.fill: parent
                                radius: 11
                                visible: !row.modelData.iconUrl && !row.modelData.image
                                color: Theme.alpha(row.rowAccent, row.selected ? 0.3 : 0.16)
                                Icon {
                                    anchors.centerIn: parent
                                    icon: row.modelData.glyph ?? "application"
                                    size: 19
                                    color: row.rowAccent
                                }
                            }
                            AppIcon {
                                anchors.fill: parent
                                visible: !!row.modelData.iconUrl
                                source: row.modelData.iconUrl ?? ""
                                size: 36
                                scale: row.selected ? 1.12 : 1
                                Behavior on scale { NumAnim { easing.bezierCurve: Motion.spatialFast } }
                            }
                            ClippingRectangle {
                                anchors.fill: parent
                                visible: !!row.modelData.image
                                radius: 10
                                color: Theme.surfaceHigh
                                Image {
                                    anchors.fill: parent
                                    source: row.modelData.image ?? ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                    sourceSize.width: 192
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Txt {
                                Layout.fillWidth: true
                                text: row.modelData.title
                                textFormat: Text.StyledText
                                font.pixelSize: 14
                                font.weight: row.selected ? Font.Bold : Font.Medium
                                maximumLineCount: 1
                            }
                            Txt {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: row.modelData.sub ?? ""
                                font.pixelSize: 11
                                color: Theme.fgDim
                                maximumLineCount: 1
                            }
                        }

                        // desktop actions for the selected app
                        Repeater {
                            model: row.selected && row.modelData.entry ? row.modelData.entry.actions.slice(0, 3) : []
                            Btn {
                                required property var modelData
                                required property int index
                                text: modelData.name
                                filled: false
                                implicitHeight: 28
                                fontSize: 11
                                pad: 10
                                onClicked: {
                                    modelData.execute();
                                    Panels.launcher = false;
                                }
                            }
                        }

                        Rectangle {
                            visible: !!row.modelData.badge
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: badgeTxt.implicitWidth + 14
                            radius: 11
                            color: Theme.alpha(row.rowAccent, 0.18)
                            Txt {
                                id: badgeTxt
                                anchors.centerIn: parent
                                text: row.modelData.badge ?? ""
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: row.rowAccent
                            }
                        }

                        IconBtn {
                            visible: !!row.modelData.del
                            icon: "trash_can_outline"
                            size: 28
                            iconSize: 14
                            iconColor: Theme.error
                            onClicked: row.modelData.del()
                        }

                        Keycap {
                            visible: row.selected
                            icon: "keyboard_return"
                            accent: win.accent
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        z: -1
                        cursorShape: Qt.PointingHandCursor
                        onEntered: list.currentIndex = row.index
                        onClicked: win.run(row.modelData, 0)
                    }
                }

                // empty state
                Column {
                    anchors.centerIn: parent
                    visible: list.count === 0 && list.visible
                    spacing: 8
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon: win.mode === "clipboard" && Clipboard.loading ? "loading" : win.current.glyph
                        size: 34
                        color: Theme.alpha(win.accent, 0.7)
                    }
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.term === "" && win.mode !== "apps" ? win.current.hint : "Nothing found"
                        color: Theme.fgDim
                    }
                }
            }
        }

        // ---------- footer ----------
        RowLayout {
            id: footer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 14
            height: 28
            spacing: 6

            Keycap { icon: "swap_vertical"; accent: win.accent }
            Txt { text: "move"; font.pixelSize: 11; color: Theme.fgDim }
            Item { implicitWidth: 6 }
            Keycap { icon: "keyboard_return"; accent: win.accent }
            Txt { text: "open"; font.pixelSize: 11; color: Theme.fgDim }
            Item { implicitWidth: 6 }
            Keycap { text: "?"; accent: win.accent }
            Txt { text: "prefixes"; font.pixelSize: 11; color: Theme.fgDim }
            Item { Layout.fillWidth: true }
            Txt {
                text: win.gridMode ? (win.emojis[emojiGrid.currentIndex]?.name ?? "") : (list.count > 0 ? list.count + (list.count === 1 ? " result" : " results") : "")
                font.pixelSize: 11
                font.weight: Font.Bold
                color: win.accent
            }
        }
    }
}
