pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services
import qs.widgets

// Live system monitor. GPU stats only poll when you ask (wakes the dGPU).
Item {
    id: root

    property bool active: false
    onActiveChanged: SysStats.procsWanted = active
    Component.onDestruction: {
        SysStats.procsWanted = false;
        SysStats.gpuWanted = false;
    }

    component StatCard: Card {
        id: sc
        property string icon
        property string title
        property string value
        property string sub
        property int accentIndex: 0
        property var series: []
        property real maxValue: 1
        property var rows: []   // [{ k, v }] shown above a thin trend line
        readonly property color accent: Theme.accent(accentIndex)
        shown: root.active

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 4
            RowLayout {
                SectionTitle {
                    Layout.fillWidth: true
                    icon: sc.icon
                    text: sc.title
                    accent: sc.accent
                }
                Txt {
                    text: sc.value
                    font.pixelSize: 22
                    font.weight: Font.Black
                    font.family: Theme.display
                    color: sc.accent
                }
            }
            Txt {
                Layout.fillWidth: true
                text: sc.sub
                font.pixelSize: 11
                color: Theme.fgDim
            }
            InfoRows {
                Layout.fillWidth: true
                Layout.topMargin: 4
                rows: sc.rows
            }
            Item { Layout.fillHeight: true }
            Graph {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                values: sc.series
                color: sc.accent
                maxValue: sc.maxValue
                lineWidth: 1.5
            }
        }
    }

    component InfoRows: ColumnLayout {
        id: ir
        property var rows: []
        spacing: 3
        Repeater {
            model: ir.rows
            RowLayout {
                id: kv
                required property var modelData
                Layout.fillWidth: true
                Txt {
                    text: kv.modelData.k
                    font.pixelSize: 11
                    color: Theme.fgDim
                    Layout.preferredWidth: 92
                }
                Txt {
                    Layout.fillWidth: true
                    text: kv.modelData.v
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.family: Theme.mono
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    GridLayout {
        anchors.fill: parent
        columns: 3
        rowSpacing: 14
        columnSpacing: 14

        StatCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            icon: "chip"
            title: "CPU"
            value: Math.round(SysStats.cpu * 100) + "%"
            sub: SysStats.cpuModel + " · " + SysStats.cores.length + " threads"
            series: SysStats.cpuHistory
            accentIndex: 0
            rows: [
                { k: "Clock", v: (SysStats.cpuMhz / 1000).toFixed(2) + " GHz avg" },
                { k: "Load (1/5/15)", v: SysStats.loadAvg },
                { k: "Processes", v: SysStats.procCount },
                { k: "Busiest core", v: Math.round(Math.max(0, ...SysStats.cores) * 100) + "%" },
                { k: "Temperature", v: Math.round(SysStats.cpuTemp) + " °C" }
            ]
        }
        StatCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            icon: "memory"
            title: "Memory"
            value: Math.round(SysStats.mem * 100) + "%"
            sub: Utils.bytes(SysStats.memUsed) + " / " + Utils.bytes(SysStats.memTotal) + " · swap " + Math.round(SysStats.swap * 100) + "%"
            series: SysStats.memHistory
            accentIndex: 3
            delay: 50
            rows: [
                { k: "Used", v: Utils.bytes(SysStats.memUsed) + " / " + Utils.bytes(SysStats.memTotal) },
                { k: "Available", v: Utils.bytes(SysStats.memAvailable) },
                { k: "Cache", v: Utils.bytes(SysStats.memCached) },
                { k: "Shared", v: Utils.bytes(SysStats.memShared) },
                { k: "Swap", v: SysStats.swapTotal > 0 ? Utils.bytes(SysStats.swapUsed) + " / " + Utils.bytes(SysStats.swapTotal) : "none" }
            ]
        }
        StatCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            icon: "thermometer"
            title: "Temperature"
            value: Math.round(SysStats.cpuTemp) + "°C"
            sub: "CPU package"
            series: SysStats.tempHistory
            accentIndex: 6
            delay: 100
            rows: [
                { k: "CPU package", v: Math.round(SysStats.cpuTemp) + " °C" },
                { k: "SSD (NVMe)", v: SysStats.nvmeTemp > 0 ? Math.round(SysStats.nvmeTemp) + " °C" : "—" },
                { k: "GPU", v: SysStats.gpuWanted && SysStats.gpuTemp > 0 ? Math.round(SysStats.gpuTemp) + " °C" : "switch GPU on" },
                { k: "Power profile", v: Power.profileName },
                { k: "Peak (last 90 s)", v: Math.round(Math.max(0, ...SysStats.tempHistory) * 100) + " °C" }
            ]
        }

        // per-core heat grid
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            shown: root.active
            delay: 120
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8
                SectionTitle {
                    icon: "grid"
                    text: "Cores"
                    accent: Theme.accent(1)
                }
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 5
                    rowSpacing: 5
                    columnSpacing: 5
                    Repeater {
                        model: SysStats.cores.length
                        Rectangle {
                            id: core
                            required property int index
                            readonly property real v: SysStats.cores[index] ?? 0
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8
                            color: Theme.mix(Theme.alpha(Theme.accent(1), 0.12), Theme.accent(Math.round(v * 6) % 10), Math.min(1, v * 1.2))
                            Behavior on color { ColAnim { duration: 700 } }
                            Txt {
                                anchors.centerIn: parent
                                text: Math.round(core.v * 100)
                                font.pixelSize: 10
                                font.family: Theme.mono
                                font.weight: Font.Bold
                                color: core.v > 0.45 ? Theme.on(parent.color) : Theme.fgDim
                            }
                        }
                    }
                }
            }
        }

        // network
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            shown: root.active
            delay: 150
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 4
                SectionTitle {
                    icon: "swap_vertical"
                    text: "Network"
                    accent: Theme.accent(5)
                }
                RowLayout {
                    Icon {
                        icon: "arrow_down"
                        size: 14
                        color: Theme.accent(5)
                    }
                    Txt {
                        text: Utils.rate(SysStats.netDown)
                        font.weight: Font.Bold
                        font.family: Theme.mono
                    }
                    Item { Layout.fillWidth: true }
                    Icon {
                        icon: "arrow_up"
                        size: 14
                        color: Theme.accent(8)
                    }
                    Txt {
                        text: Utils.rate(SysStats.netUp)
                        font.weight: Font.Bold
                        font.family: Theme.mono
                    }
                }
                InfoRows {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    rows: [
                        { k: "Connection", v: Net.wiredUp ? "Ethernet" : (Net.active?.name ?? "offline") },
                        { k: "Signal", v: Net.active ? Math.round(Net.strength * 100) + "%" : "—" },
                        { k: "Interface", v: SysStats.netIface || "—" },
                        { k: "IP address", v: SysStats.netIp || "—" },
                        { k: "Since shell start", v: "↓ " + Utils.bytes(SysStats.rxTotal) + "  ↑ " + Utils.bytes(SysStats.txTotal) }
                    ]
                }
                Item { Layout.fillHeight: true }
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    Graph {
                        anchors.fill: parent
                        lineWidth: 1.5
                        values: SysStats.downHistory
                        maxValue: Math.max(1024 * 64, ...SysStats.downHistory, ...SysStats.upHistory)
                        color: Theme.accent(5)
                    }
                    Graph {
                        anchors.fill: parent
                        lineWidth: 1.5
                        values: SysStats.upHistory
                        maxValue: Math.max(1024 * 64, ...SysStats.downHistory, ...SysStats.upHistory)
                        color: Theme.accent(8)
                        fillArea: false
                    }
                }
            }
        }

        // GPU (on demand)
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            shown: root.active
            delay: 180
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 6
                RowLayout {
                    SectionTitle {
                        Layout.fillWidth: true
                        icon: "expansion_card"
                        text: "GPU"
                        accent: Theme.accent(7)
                    }
                    StyledSwitch {
                        checked: SysStats.gpuWanted
                        accent: Theme.accent(7)
                        onToggled: v => SysStats.gpuWanted = v
                    }
                }
                Txt {
                    Layout.fillWidth: true
                    visible: !SysStats.gpuWanted
                    wrapMode: Text.Wrap
                    text: "Polling nvidia-smi keeps the NVIDIA GPU awake, so it's off until you flip the switch."
                    font.pixelSize: 11
                    color: Theme.fgDim
                }
                Txt {
                    visible: SysStats.gpuWanted
                    Layout.fillWidth: true
                    text: SysStats.gpuName || "Waking the GPU…"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: Theme.accent(7)
                }
                InfoRows {
                    visible: SysStats.gpuWanted
                    Layout.fillWidth: true
                    rows: [
                        { k: "Usage", v: Math.round(SysStats.gpu * 100) + "%  ·  " + SysStats.gpuPstate },
                        { k: "Temperature", v: Math.round(SysStats.gpuTemp) + " °C" },
                        { k: "Power draw", v: SysStats.gpuPower.toFixed(1) + " / " + SysStats.gpuPowerLimit.toFixed(0) + " W" },
                        { k: "VRAM", v: Utils.bytes(SysStats.gpuMemUsed) + " / " + Utils.bytes(SysStats.gpuMemTotal) },
                        { k: "Clocks", v: SysStats.gpuClock + " / " + SysStats.gpuMemClock + " MHz" },
                        { k: "Fan", v: SysStats.gpuFan }
                    ]
                }
                Txt {
                    visible: SysStats.gpuWanted
                    Layout.topMargin: 4
                    text: "Top GPU processes"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: Theme.fgDim
                }
                Repeater {
                    model: SysStats.gpuWanted ? SysStats.gpuProcs : []
                    RowLayout {
                        id: gp
                        required property var modelData
                        Layout.fillWidth: true
                        Txt {
                            Layout.fillWidth: true
                            text: gp.modelData.name + "  (" + (gp.modelData.type === "G" ? "graphics" : gp.modelData.type === "C" ? "compute" : gp.modelData.type) + ")"
                            font.pixelSize: 11
                            font.family: Theme.mono
                        }
                        Txt {
                            text: gp.modelData.sm + "% · mem " + gp.modelData.mem + "%"
                            font.pixelSize: 11
                            font.family: Theme.mono
                            color: Theme.fgDim
                        }
                    }
                }
                Txt {
                    visible: SysStats.gpuWanted && SysStats.gpuProcs.length === 0
                    text: "nothing is using the GPU"
                    font.pixelSize: 11
                    color: Theme.fgDim
                }
                Item {
                    visible: SysStats.gpuWanted
                    Layout.fillHeight: true
                }
                Item {
                    visible: !SysStats.gpuWanted
                    Layout.fillHeight: true
                }
            }
        }

        // top processes
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.columnSpan: 2
            shown: root.active
            delay: 210
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 4
                SectionTitle {
                    icon: "format_list_bulleted"
                    text: "Top processes"
                    accent: Theme.accent(2)
                }
                Repeater {
                    model: SysStats.topProcs.slice(0, 6)
                    RowLayout {
                        id: proc
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 10
                        Txt {
                            Layout.preferredWidth: 160
                            text: proc.modelData.name
                            font.family: Theme.mono
                            font.pixelSize: 12
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            radius: 3
                            color: Theme.alpha(Theme.fg, 0.07)
                            Rectangle {
                                height: parent.height
                                radius: 3
                                width: parent.width * Math.min(1, proc.modelData.cpu / (100 * Math.max(1, SysStats.cores.length) / 4))
                                color: Theme.accent(proc.index + 2)
                                Behavior on width { NumAnim {} }
                            }
                        }
                        Txt {
                            Layout.preferredWidth: 60
                            horizontalAlignment: Text.AlignRight
                            text: proc.modelData.cpu.toFixed(1) + "%"
                            font.family: Theme.mono
                            font.pixelSize: 11
                            color: Theme.fgDim
                        }
                        Txt {
                            Layout.preferredWidth: 60
                            horizontalAlignment: Text.AlignRight
                            text: proc.modelData.mem.toFixed(1) + "%"
                            font.family: Theme.mono
                            font.pixelSize: 11
                            color: Theme.fgDim
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        // system info
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            shown: root.active
            delay: 240
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 6
                SectionTitle {
                    icon: "information_outline"
                    text: SysStats.hostname || "System"
                    accent: Theme.accent(9)
                }
                Repeater {
                    model: [
                        { k: "Kernel", v: SysStats.kernel },
                        { k: "Uptime", v: Utils.human(SysStats.uptime) },
                        { k: "Disk /", v: Utils.bytes(SysStats.diskUsed) + " / " + Utils.bytes(SysStats.diskTotal) },
                        { k: "Battery", v: Power.percent + "% · " + Power.statusText },
                        { k: "Profile", v: Power.profileName },
                        { k: "Draw", v: Power.rate > 0 ? Power.rate.toFixed(1) + " W" : "—" }
                    ]
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Txt {
                            text: parent.modelData.k
                            font.pixelSize: 11
                            color: Theme.fgDim
                            Layout.preferredWidth: 60
                        }
                        Txt {
                            Layout.fillWidth: true
                            text: parent.modelData.v
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
