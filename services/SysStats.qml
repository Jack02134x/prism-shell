pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// CPU / memory / temperature / network from /proc and sysfs. GPU (nvidia-smi)
// only polls while `gpuWanted` is set, so the dGPU can stay asleep.
Singleton {
    id: root

    readonly property int historySize: 60
    property real cpu: 0
    property var cores: []
    property var cpuHistory: []
    property real mem: 0
    property real memUsed: 0
    property real memTotal: 0
    property real swap: 0
    property var memHistory: []
    property real cpuTemp: 0
    property var tempHistory: []
    property real netDown: 0
    property real netUp: 0
    property var downHistory: []
    property var upHistory: []
    property real uptime: 0
    property string cpuModel: ""
    property string hostname: ""
    property string kernel: ""
    property real diskUsed: 0
    property real diskTotal: 0

    // detail for the System tab
    property string loadAvg: ""
    property int procCount: 0
    property real cpuMhz: 0
    property real memAvailable: 0
    property real memCached: 0
    property real memBuffers: 0
    property real memShared: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property real nvmeTemp: 0
    property string netIface: ""
    property string netIp: ""
    property real rxTotal: 0
    property real txTotal: 0
    property var netStart: null

    property bool gpuWanted: false
    property real gpuPowerLimit: 0
    property real gpuClock: 0
    property real gpuMemClock: 0
    property string gpuFan: ""
    property string gpuPstate: ""
    property var gpuProcs: []
    property real gpu: 0
    property real gpuTemp: 0
    property real gpuMemUsed: 0
    property real gpuMemTotal: 0
    property real gpuPower: 0
    property string gpuName: ""
    property var gpuHistory: []

    property var prevCpu: []
    property var prevNet: null
    property string tempPath: ""

    function push(arr, v) {
        const a = arr.slice(-(historySize - 1));
        a.push(v);
        return a;
    }

    FileView { id: statFile; path: "/proc/stat"; blockLoading: true }
    FileView { id: memFile; path: "/proc/meminfo"; blockLoading: true }
    FileView { id: netFile; path: "/proc/net/dev"; blockLoading: true }
    FileView { id: upFile; path: "/proc/uptime"; blockLoading: true }
    FileView { id: tempFile; path: root.tempPath; blockLoading: true }
    FileView { id: loadFile; path: "/proc/loadavg"; blockLoading: true }
    FileView { id: nvmeFile; path: root.nvmePath; blockLoading: true }
    property string nvmePath: ""

    Timer {
        interval: 1500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
            netFile.reload();
            upFile.reload();
            if (root.tempPath !== "")
                tempFile.reload();
            loadFile.reload();
            if (root.nvmePath !== "")
                nvmeFile.reload();
            root.sample();
        }
    }

    function sample() {
        // CPU
        const lines = statFile.text().split("\n").filter(l => l.startsWith("cpu"));
        const now = lines.map(l => {
            const f = l.trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + (f[4] || 0);
            const total = f.reduce((a, b) => a + b, 0);
            return [idle, total];
        });
        if (prevCpu.length === now.length) {
            const use = now.map((v, i) => {
                const di = v[0] - prevCpu[i][0], dt = v[1] - prevCpu[i][1];
                return dt > 0 ? 1 - di / dt : 0;
            });
            cpu = use[0];
            cores = use.slice(1);
            cpuHistory = push(cpuHistory, cpu);
        }
        prevCpu = now;

        // memory
        const mi = {};
        for (const l of memFile.text().split("\n")) {
            const m = l.match(/^(\w+):\s+(\d+)/);
            if (m)
                mi[m[1]] = parseInt(m[2]) * 1024;
        }
        if (mi.MemTotal) {
            memTotal = mi.MemTotal;
            memUsed = mi.MemTotal - mi.MemAvailable;
            mem = memUsed / memTotal;
            swap = mi.SwapTotal > 0 ? 1 - mi.SwapFree / mi.SwapTotal : 0;
            memAvailable = mi.MemAvailable;
            memCached = (mi.Cached ?? 0) + (mi.SReclaimable ?? 0);
            memBuffers = mi.Buffers ?? 0;
            memShared = mi.Shmem ?? 0;
            swapTotal = mi.SwapTotal ?? 0;
            swapUsed = (mi.SwapTotal ?? 0) - (mi.SwapFree ?? 0);
            memHistory = push(memHistory, mem);
        }

        // network (all non-loopback interfaces)
        let rx = 0, tx = 0;
        for (const l of netFile.text().split("\n").slice(2)) {
            const m = l.trim().split(/[:\s]+/);
            if (m.length < 10 || m[0] === "lo" || m[0].startsWith("docker") || m[0].startsWith("veth"))
                continue;
            rx += Number(m[1]);
            tx += Number(m[9]);
        }
        const t = Date.now();
        if (prevNet) {
            const dt = (t - prevNet.t) / 1000;
            netDown = Math.max(0, (rx - prevNet.rx) / dt);
            netUp = Math.max(0, (tx - prevNet.tx) / dt);
            downHistory = push(downHistory, netDown);
            upHistory = push(upHistory, netUp);
        }
        prevNet = { rx, tx, t };
        if (!netStart)
            netStart = { rx, tx };
        rxTotal = rx - netStart.rx;
        txTotal = tx - netStart.tx;

        const la = loadFile.text().trim().split(/\s+/);
        if (la.length >= 4) {
            loadAvg = la.slice(0, 3).join("  ");
            procCount = parseInt(la[3].split("/")[1]) || 0;
        }
        if (nvmePath !== "") {
            const nv = parseInt(nvmeFile.text());
            if (!isNaN(nv))
                nvmeTemp = nv / 1000;
        }

        uptime = parseFloat(upFile.text()) || uptime;

        if (tempPath !== "") {
            const v = parseInt(tempFile.text());
            if (!isNaN(v)) {
                cpuTemp = v / 1000;
                tempHistory = push(tempHistory, cpuTemp / 100);
            }
        }
    }

    // static-ish info: cpu model, hostname, kernel, coretemp sensor path
    Process {
        running: true
        command: ["sh", "-c", "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2; cat /proc/sys/kernel/hostname; uname -r; for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name); if [ \"$n\" = coretemp ] || [ \"$n\" = k10temp ] || [ \"$n\" = zenpower ]; then echo $h/temp1_input; break; fi; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.cpuModel = (l[0] ?? "").trim().replace(/\(R\)|\(TM\)/g, "");
                root.hostname = (l[1] ?? "").trim();
                root.kernel = (l[2] ?? "").trim();
                root.tempPath = (l[3] ?? "").trim();
            }
        }
    }

    Process {
        id: infoProc
        command: ["sh", "-c", "awk -F: '/cpu MHz/{s+=$2;n++} END{if(n) printf \"%d\\n\", s/n; else print 0}' /proc/cpuinfo; ip -4 -o addr show scope global | awk '{print $2, $4; exit}'; for h in /sys/class/hwmon/hwmon*; do [ \"$(cat $h/name)\" = nvme ] && { echo $h/temp1_input; break; }; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.cpuMhz = parseFloat(l[0]) || 0;
                const ip = (l[1] ?? "").trim().split(" ");
                root.netIface = ip[0] ?? "";
                root.netIp = (ip[1] ?? "").split("/")[0];
                if ((l[2] ?? "").trim() !== "")
                    root.nvmePath = l[2].trim();
            }
        }
    }
    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: if (!infoProc.running) infoProc.running = true
    }

    Process {
        id: dfProc
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("\n")[1]?.trim().split(/\s+/) ?? [];
                root.diskUsed = Number(p[0]) || 0;
                root.diskTotal = Number(p[1]) || 0;
            }
        }
    }
    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: dfProc.running = true
    }

    Process {
        id: gpuProc
        command: ["sh", "-c", "nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,power.limit,clocks.gr,clocks.mem,fan.speed,pstate --format=csv,noheader,nounits; echo ::PROCS::; nvidia-smi pmon -c 1 -s um 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [head, procs] = text.split("::PROCS::");
                const p = (head ?? "").trim().split(",").map(s => s.trim());
                if (p.length < 6)
                    return;
                root.gpuPowerLimit = parseFloat(p[6]) || 0;
                root.gpuClock = parseFloat(p[7]) || 0;
                root.gpuMemClock = parseFloat(p[8]) || 0;
                root.gpuFan = /\d/.test(p[9] ?? "") ? p[9] + "%" : "—";
                root.gpuPstate = p[10] ?? "";
                // pmon: # gpu pid type sm mem enc dec ... command
                const list = [];
                for (const line of (procs ?? "").split("\n")) {
                    const f = line.trim().split(/\s+/);
                    if (f.length < 6 || f[0].startsWith("#") || f[1] === "-")
                        continue;
                    list.push({ pid: f[1], type: f[2], sm: parseFloat(f[3]) || 0, mem: parseFloat(f[4]) || 0, name: f[f.length - 1] });
                }
                root.gpuProcs = list.sort((a, b) => b.sm - a.sm || b.mem - a.mem).slice(0, 6);
                root.gpuName = p[0];
                root.gpu = (parseFloat(p[1]) || 0) / 100;
                root.gpuTemp = parseFloat(p[2]) || 0;
                root.gpuMemUsed = (parseFloat(p[3]) || 0) * 1048576;
                root.gpuMemTotal = (parseFloat(p[4]) || 0) * 1048576;
                root.gpuPower = parseFloat(p[5]) || 0;
                root.gpuHistory = root.push(root.gpuHistory, root.gpu);
            }
        }
    }
    Timer {
        interval: 2000
        repeat: true
        running: root.gpuWanted
        triggeredOnStart: true
        onTriggered: if (!gpuProc.running) gpuProc.running = true
    }

    // top processes, on demand
    property var topProcs: []
    property bool procsWanted: false
    Process {
        id: psProc
        command: ["ps", "-eo", "pid,pcpu,pmem,comm", "--sort=-pcpu", "--no-headers"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.topProcs = text.trim().split("\n").slice(0, 8).map(l => {
                    const p = l.trim().split(/\s+/);
                    return { pid: p[0], cpu: parseFloat(p[1]) || 0, mem: parseFloat(p[2]) || 0, name: p.slice(3).join(" ") };
                });
            }
        }
    }
    Timer {
        interval: 2500
        repeat: true
        running: root.procsWanted
        triggeredOnStart: true
        onTriggered: if (!psProc.running) psProc.running = true
    }
}
