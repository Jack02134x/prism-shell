pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.services
import qs.widgets

// 3D coverflow wallpaper picker with a live blurred preview and a palette
// preview of the centred image. Enter / click the centre card to apply (the
// awww transition grows from where you clicked); Tab switches static / live.
Overlay {
    id: win

    name: "wallpapers"
    open: Panels.wallpapers
    scrimOpacity: 0.5
    openDuration: Motion.slower
    onDismiss: Panels.wallpapers = false
    onOpened: {
        Wallpapers.load();
        search.text = Panels.wallpaperQuery;
        search.focusInput();
        jumpToCurrent();
    }

    property bool live: false
    readonly property var source: live ? Wallpapers.videos : Wallpapers.images
    readonly property string q: search.text.trim().toLowerCase()
    readonly property var items: q === "" ? source : source.filter(p => Utils.fileName(p).toLowerCase().includes(q))
    readonly property string currentPath: items[view.currentIndex] ?? ""

    function thumbOf(p) {
        return live ? Wallpapers.videoThumb(p) : Wallpapers.thumb(p);
    }
    function jumpToCurrent() {
        const i = items.indexOf(Theme.wallpaper);
        view.currentIndex = i >= 0 ? i : 0;
    }
    function apply(x, y) {
        if (currentPath === "")
            return;
        Panels.wallpapers = false;
        if (live)
            Wallpapers.applyVideo(currentPath);
        else
            Wallpapers.apply(currentPath, x, y);
    }

    onItemsChanged: if (view.currentIndex >= items.length) view.currentIndex = 0
    Connections {
        target: Wallpapers
        function onLoadedChanged() {
            if (win.open)
                win.jumpToCurrent();
        }
    }

    // ---- live blurred preview of the centred wallpaper ----
    Item {
        anchors.fill: parent
        opacity: win.progress
        Image {
            id: previewSrc
            property bool fallback: false
            property string path: win.currentPath
            onPathChanged: fallback = false
            anchors.fill: parent
            source: path === "" ? "" : fallback ? "file://" + path : win.thumbOf(path)
            sourceSize.width: 640
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
            onStatusChanged: if (status === Image.Error && !fallback && !win.live) fallback = true
        }
        MultiEffect {
            anchors.fill: parent
            source: previewSrc
            blurEnabled: true
            blur: 1
            blurMax: 48
            brightness: -0.3
            saturation: 0.2
        }
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: Config.bar.height + Config.bar.margin + 24
        anchors.bottomMargin: 36
        opacity: win.progress

        // ---- toolbar ----
        RowLayout {
            id: toolbar
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            z: 200
            spacing: 12

            Rectangle {
                implicitHeight: 46
                implicitWidth: tabsRow.implicitWidth + 8
                radius: 23
                color: Theme.alpha(Theme.surface, 0.85)
                Rectangle {
                    x: win.live ? tabLive.x + 4 : tabStatic.x + 4
                    y: 4
                    width: win.live ? tabLive.width : tabStatic.width
                    height: 38
                    radius: 19
                    color: Theme.accent(win.live ? 6 : 0)
                    Behavior on x { NumAnim { easing.bezierCurve: Motion.spatial } }
                    Behavior on width { NumAnim {} }
                    Behavior on color { ColAnim {} }
                }
                RowLayout {
                    id: tabsRow
                    anchors.centerIn: parent
                    spacing: 0
                    Item {
                        id: tabStatic
                        implicitWidth: ts.implicitWidth + 32
                        implicitHeight: 38
                        RowLayout {
                            id: ts
                            anchors.centerIn: parent
                            Icon {
                                icon: "image"
                                size: 16
                                color: win.live ? Theme.fg : Theme.on(Theme.accent(0))
                            }
                            Txt {
                                text: "Static · " + Wallpapers.images.length
                                font.weight: Font.Bold
                                color: win.live ? Theme.fg : Theme.on(Theme.accent(0))
                            }
                        }
                        TapHandler {
                            onTapped: win.live = false
                        }
                    }
                    Item {
                        id: tabLive
                        implicitWidth: tl.implicitWidth + 32
                        implicitHeight: 38
                        RowLayout {
                            id: tl
                            anchors.centerIn: parent
                            Icon {
                                icon: "filmstrip"
                                size: 16
                                color: win.live ? Theme.on(Theme.accent(6)) : Theme.fg
                            }
                            Txt {
                                text: "Live · " + Wallpapers.videos.length
                                font.weight: Font.Bold
                                color: win.live ? Theme.on(Theme.accent(6)) : Theme.fg
                            }
                        }
                        TapHandler {
                            onTapped: win.live = true
                        }
                    }
                }
            }

            InputField {
                id: search
                Layout.preferredWidth: 420
                placeholder: "Search " + win.source.length + " wallpapers…"
                accent: Theme.accent(win.live ? 6 : 0)
                horizontalNav: true
                onNavigate: (delta, vertical) => {
                    if (vertical) {
                        win.live = !win.live;
                        return;
                    }
                    if (delta > 0)
                        view.incrementCurrentIndex();
                    else
                        view.decrementCurrentIndex();
                }
                onAccepted: win.apply()
            }

            IconBtn {
                icon: "dice_multiple"
                size: 46
                active: true
                accent: Theme.accent(3)
                tooltip: "Random"
                onClicked: view.currentIndex = Math.floor(Math.random() * win.items.length)
            }
            IconBtn {
                visible: win.live
                icon: "stop"
                size: 46
                active: true
                accent: Theme.accent(8)
                tooltip: "Stop live wallpaper"
                onClicked: Wallpapers.stopLive()
            }
        }

        // ---- coverflow ----
        PathView {
            id: view
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: toolbar.bottom
            anchors.bottom: info.top
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            model: win.items
            pathItemCount: 9
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            highlightMoveDuration: 380
            snapMode: PathView.SnapToItem
            cacheItemCount: 4
            readonly property real cy: height / 2

            path: Path {
                startX: -view.width * 0.05
                startY: view.cy
                PathAttribute { name: "itemScale"; value: 0.42 }
                PathAttribute { name: "itemAngle"; value: 58 }
                PathAttribute { name: "itemZ"; value: 0 }
                PathAttribute { name: "itemOpacity"; value: 0.25 }
                PathLine { x: view.width * 0.38; y: view.cy }
                PathPercent { value: 0.42 }
                PathAttribute { name: "itemScale"; value: 0.66 }
                PathAttribute { name: "itemAngle"; value: 42 }
                PathAttribute { name: "itemZ"; value: 50 }
                PathAttribute { name: "itemOpacity"; value: 0.85 }
                PathLine { x: view.width * 0.5; y: view.cy }
                PathPercent { value: 0.5 }
                PathAttribute { name: "itemScale"; value: 1.0 }
                PathAttribute { name: "itemAngle"; value: 0 }
                PathAttribute { name: "itemZ"; value: 100 }
                PathAttribute { name: "itemOpacity"; value: 1 }
                PathLine { x: view.width * 0.62; y: view.cy }
                PathPercent { value: 0.58 }
                PathAttribute { name: "itemScale"; value: 0.66 }
                PathAttribute { name: "itemAngle"; value: -42 }
                PathAttribute { name: "itemZ"; value: 50 }
                PathAttribute { name: "itemOpacity"; value: 0.85 }
                PathLine { x: view.width * 1.05; y: view.cy }
                PathPercent { value: 1 }
                PathAttribute { name: "itemScale"; value: 0.42 }
                PathAttribute { name: "itemAngle"; value: -58 }
                PathAttribute { name: "itemZ"; value: 0 }
                PathAttribute { name: "itemOpacity"; value: 0.25 }
            }

            delegate: Item {
                id: wp
                required property string modelData
                required property int index
                readonly property bool isCurrent: PathView.isCurrentItem
                readonly property bool isActiveWall: modelData === Theme.wallpaper
                width: Math.min(720, view.width * 0.42, view.height * 0.95 * 16 / 9)
                height: width * 9 / 16
                scale: PathView.itemScale ?? 0.4
                z: PathView.itemZ ?? 0
                opacity: PathView.itemOpacity ?? 0
                transform: Rotation {
                    origin.x: wp.width / 2
                    origin.y: wp.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: wp.PathView.itemAngle ?? 0
                }

                // glow behind the centred card
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -10
                    radius: 34
                    visible: wp.isCurrent
                    color: Theme.alpha(Theme.accent(win.live ? 6 : 0), 0.35)
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: 24
                    color: Theme.surfaceHigh
                    border.width: wp.isCurrent ? 3 : 1
                    border.color: wp.isCurrent ? Theme.accent(win.live ? 6 : 0) : Theme.alpha(Theme.outline, 0.4)

                    Image {
                        id: img
                        anchors.fill: parent
                        property bool fallback: false
                        source: fallback ? "file://" + wp.modelData : win.thumbOf(wp.modelData)
                        sourceSize.width: fallback ? 640 : 512
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        onStatusChanged: if (status === Image.Error && !fallback && !win.live) fallback = true
                    }
                    // sharp full-res version for the centre card
                    Image {
                        anchors.fill: parent
                        visible: wp.isCurrent && !win.live && status === Image.Ready
                        source: wp.isCurrent && !win.live ? "file://" + wp.modelData : ""
                        sourceSize.width: 1280
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: img.status !== Image.Ready
                        icon: win.live ? "filmstrip" : "image"
                        size: 48
                        color: Theme.alpha(Theme.fg, 0.3)
                    }
                    Rectangle {
                        visible: win.live
                        anchors.centerIn: parent
                        width: 64
                        height: 64
                        radius: 32
                        color: Qt.rgba(0, 0, 0, 0.45)
                        Icon {
                            anchors.centerIn: parent
                            icon: "play"
                            size: 34
                            color: "white"
                        }
                    }
                    Rectangle {
                        visible: wp.isActiveWall
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 14
                        implicitWidth: cur.implicitWidth + 18
                        implicitHeight: 26
                        radius: 13
                        color: Theme.accent(2)
                        Txt {
                            id: cur
                            anchors.centerIn: parent
                            text: "current"
                            font.pixelSize: 11
                            font.weight: Font.Black
                            color: Theme.on(Theme.accent(2))
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (wp.isCurrent) {
                            const p = mapToItem(win.contentRoot, mouse.x, mouse.y);
                            win.apply(p.x, p.y);
                        } else {
                            view.currentIndex = wp.index;
                        }
                    }
                }
            }
        }

        // ---- info + palette ----
        ColumnLayout {
            id: info
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            z: 200
            spacing: 10

            Txt {
                Layout.alignment: Qt.AlignHCenter
                text: win.currentPath !== "" ? Utils.stem(win.currentPath) : (Wallpapers.loaded ? "No wallpapers match" : "Loading wallpapers…")
                font.pixelSize: 20
                font.weight: Font.Black
                font.family: Theme.display
                color: "white"
                Layout.maximumWidth: 900
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                visible: !win.live
                Repeater {
                    model: quant.colors.slice(0, 8)
                    Rectangle {
                        required property color modelData
                        required property int index
                        implicitWidth: 34
                        implicitHeight: 34
                        radius: 10
                        color: modelData
                        border.width: 2
                        border.color: Qt.rgba(1, 1, 1, 0.25)
                        scale: 0
                        Component.onCompleted: popIn.start()
                        NumberAnimation on scale {
                            id: popIn
                            running: false
                            from: 0
                            to: 1
                            duration: 380
                            easing.type: Easing.OutBack
                        }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                Txt {
                    text: (win.items.length > 0 ? (view.currentIndex + 1) + " / " + win.items.length : "")
                    font.family: Theme.mono
                    font.pixelSize: 12
                    color: Qt.rgba(1, 1, 1, 0.7)
                }
                Txt {
                    visible: Wallpapers.thumbing
                    text: "·  building thumbnails in the background…"
                    font.pixelSize: 12
                    color: Theme.accent(3)
                }
                Btn {
                    icon: "check"
                    text: win.live ? "Play live wallpaper" : "Apply"
                    accent: Theme.accent(win.live ? 6 : 0)
                    onClicked: win.apply()
                }
            }

            Txt {
                Layout.alignment: Qt.AlignHCenter
                text: "←/→ browse   ·   ↑/↓ static / live   ·   Enter apply   ·   click the centre card to apply from that spot"
                font.pixelSize: 11
                color: Qt.rgba(1, 1, 1, 0.55)
            }
        }
    }

    ColorQuantizer {
        id: quant
        source: win.open && !win.live && previewSrc.status === Image.Ready ? previewSrc.source : ""
        depth: 3
        rescaleSize: 64
    }

    WheelHandler {
        onWheel: event => {
            if (event.angleDelta.y < 0 || event.angleDelta.x < 0)
                view.incrementCurrentIndex();
            else
                view.decrementCurrentIndex();
        }
    }
}
