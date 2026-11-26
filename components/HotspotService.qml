import Quickshell
import Quickshell.Io
import QtQuick

// Раздача Wi-Fi (scripts/hotspot.sh): состояние, имя/пароль, подключённые устройства.
// В shell.qml создаётся как `HotspotService { id: hotspot }`, панели обращаются к `hotspot`.
Scope {
    id: hs

    readonly property string script: root.configPath + "/scripts/hotspot.sh"
    readonly property string stateFile: root.statePath + "/hotspot.json"

    property bool active: false
    property bool busy: false            // идёт включение/выключение/перезапуск
    property string ssid: ""
    property string password: ""
    property var clients: []             // [{ mac, ip, name, blocked }]
    property string error: ""
    property bool loaded: false
    property bool watch: false           // панель с устройствами открыта — опрашивать чаще

    function toggle() {
        if (busy) return
        if (active) stop()
        else start(ssid, password)
    }

    function start(newSsid, newPass) {
        if (busy) return
        if (!loaded) return
        error = ""
        ssid = newSsid
        password = newPass
        save()
        busy = true
        runProc.output = ""
        runProc.command = [script, "start", newSsid, newPass]
        runProc.running = true
    }

    function stop() {
        if (busy) return
        error = ""
        busy = true
        runProc.output = ""
        runProc.command = [script, "stop"]
        runProc.running = true
    }

    function kick(mac) { actionProc.exec([script, "kick", mac]) }
    function unblock(mac) { actionProc.exec([script, "unblock", mac]) }

    function save() {
        saveProc.command = ["bash", "-c", 'mkdir -p "$(dirname "$2")" && umask 077 && printf "%s\\n" "$1" > "$2"', "_",
                            JSON.stringify({ ssid: ssid, password: password }), stateFile]
        saveProc.running = true
    }

    function randomPass() {
        var abc = "abcdefghijkmnpqrstuvwxyz23456789"
        var s = ""
        for (var i = 0; i < 10; i++) s += abc[Math.floor(Math.random() * abc.length)]
        return s
    }

    function refresh() {
        if (!statusProc.running) statusProc.running = true
    }

    function refreshClients() {
        if (active && !clientsProc.running) {
            clientsProc.buf = []
            clientsProc.running = true
        }
    }

    function notify(title, body) {
        notifyProc.command = ["notify-send", "-a", "Quickshell", "-i", "network-wireless-hotspot", title, body]
        notifyProc.running = true
    }

    Process { id: notifyProc }
    Process { id: saveProc }

    Process {
        id: loadProc
        running: true
        command: ["bash", "-c", 'cat "$1" 2>/dev/null; true', "_", hs.stateFile]
        property string buf: ""
        stdout: SplitParser { splitMarker: ""; onRead: data => loadProc.buf += data }
        onExited: {
            var cfg = {}
            try { cfg = JSON.parse(loadProc.buf) } catch (e) {}
            hs.ssid = cfg.ssid || ((Quickshell.env("USER") || "arch") + "-hotspot")
            hs.password = cfg.password || hs.randomPass()
            hs.loaded = true
            if (!cfg.ssid || !cfg.password) hs.save()
        }
    }

    Process {
        id: statusProc
        command: [hs.script, "status"]
        stdout: SplitParser {
            onRead: data => {
                var st = data.trim()
                if (hs.busy) return
                var was = hs.active
                hs.active = st === "active" || st === "activating"
                if (!hs.active) hs.clients = []
                else if (!was) hs.refreshClients()
            }
        }
    }

    Process {
        id: runProc
        property string output: ""
        stdout: SplitParser { onRead: data => runProc.output = data.trim() }
        onExited: (code) => {
            var starting = runProc.command[1] === "start"
            hs.busy = false
            if (code !== 0) {
                var msg = runProc.output.replace(/^ERR:\s*/, "") || "не удалось"
                hs.error = msg
                hs.active = false
                hs.notify("Раздача Wi-Fi", msg)
            } else {
                hs.active = starting
            }
            if (!hs.active) hs.clients = []
            hs.refresh()
            hs.refreshClients()
        }
    }

    Process {
        id: clientsProc
        property var buf: []
        command: [hs.script, "clients"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.split("\t")
                if (p.length < 4) return
                clientsProc.buf.push({ mac: p[0], ip: p[1], name: p[2], blocked: p[3].trim() === "1" })
            }
        }
        onExited: hs.clients = clientsProc.buf
    }

    Process {
        id: actionProc
        function exec(cmd) {
            if (running) return
            command = cmd
            running = true
        }
        stdout: SplitParser {
            onRead: data => { if (data.indexOf("ERR:") === 0) hs.notify("Раздача Wi-Fi", data.slice(4).trim()) }
        }
        onExited: hs.refreshClients()
    }

    Timer {
        interval: hs.watch ? 2000 : 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            hs.refresh()
            if (hs.watch) hs.refreshClients()
        }
    }
}
