import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Пульт управления: быстрые переключатели, устройства с зарядом,
// мониторы (раскладка/режим/поворот/масштаб) и тема курсора.
Item {
    id: cc

    readonly property bool shown: root.launcherVisible && root.activeTab === 3
    readonly property string ff: "JetBrainsMono Nerd Font"
    readonly property string script: root.configPath + "/scripts/control-center.py"

    function a(c, al) { return Qt.rgba(c.r, c.g, c.b, al) }
    function norm(v) { return v > 1.0001 ? v / 100 : v }
    function slug(s) { return (s || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") }

    onShownChanged: if (shown) refreshAll()

    function refreshAll() {
        if (!monDirty && !monProc.running) monProc.running = true
        if (!inputsProc.running) inputsProc.running = true
        if (!cursorsLoaded && !cursorListProc.running) cursorListProc.running = true
        if (!cursorCurProc.running) cursorCurProc.running = true
        if (!dndGetProc.running) dndGetProc.running = true
        rebuildDevices()
    }

    Timer {
        interval: 2000
        repeat: true
        running: cc.shown
        onTriggered: {
            cc.rebuildDevices()
            if (!inputsProc.running) inputsProc.running = true
        }
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            root.launcherVisible = false
            event.accepted = true
        } else if (event.key === Qt.Key_Tab) {
            root.activeTab = 0
            event.accepted = true
        }
    }

    // ════════════════════════ Устройства ════════════════════════

    property var devices: []
    property var inputGroups: []
    property string menuKey: ""        // плитка с открытым меню «Забыть»

    function btGlyph(icon, name) {
        var s = ((icon || "") + " " + (name || "")).toLowerCase()
        if (s.indexOf("headset") >= 0 || s.indexOf("barracuda") >= 0) return "\u{F02CE}"
        if (s.indexOf("headphone") >= 0 || s.indexOf("buds") >= 0 || s.indexOf("pods") >= 0) return "\u{F02CB}"
        if (s.indexOf("speaker") >= 0 || s.indexOf("audio") >= 0) return "\u{F04C3}"
        if (s.indexOf("mouse") >= 0) return "\u{F037D}"
        if (s.indexOf("keyboard") >= 0) return "\u{F030C}"
        if (s.indexOf("gaming") >= 0 || s.indexOf("joystick") >= 0 || s.indexOf("controller") >= 0) return "\u{F0297}"
        if (s.indexOf("phone") >= 0) return "\u{F011C}"
        if (s.indexOf("computer") >= 0) return "\u{F0322}"
        return "\u{F00AF}"
    }

    function upGlyph(t) {
        if (t === UPowerDeviceType.Mouse) return "\u{F037D}"
        if (t === UPowerDeviceType.Keyboard) return "\u{F030C}"
        if (t === UPowerDeviceType.Headset) return "\u{F02CE}"
        if (t === UPowerDeviceType.Headphones) return "\u{F02CB}"
        if (t === UPowerDeviceType.Speakers || t === UPowerDeviceType.OtherAudio) return "\u{F04C3}"
        if (t === UPowerDeviceType.GamingInput) return "\u{F0297}"
        if (t === UPowerDeviceType.Phone) return "\u{F011C}"
        return "\u{F0079}"
    }

    function isCharging(st) {
        return st === UPowerDeviceState.Charging || st === UPowerDeviceState.PendingCharge
    }

    function rebuildDevices() {
        var list = []
        var upByMac = {}
        var periph = []
        var ups = UPower.devices ? UPower.devices.values : []
        for (var i = 0; i < ups.length; i++) {
            var u = ups[i]
            if (!u || u.type === UPowerDeviceType.LinePower) continue
            if (u.isLaptopBattery) {
                list.push({
                    key: "laptop", name: "Ноутбук", glyph: "\u{F0322}", conn: "internal",
                    battery: cc.norm(u.percentage), charging: cc.isCharging(u.state),
                    plugged: !UPower.onBattery, connected: true, busy: false, dev: null
                })
                continue
            }
            var mm = /dev_([0-9A-Fa-f]{2}(_[0-9A-Fa-f]{2}){5})/.exec(u.nativePath || "")
            if (mm) { upByMac[mm[1].replace(/_/g, ":").toUpperCase()] = u; continue }
            if (u.type === UPowerDeviceType.Battery) continue
            var tag = (u.nativePath || "") + " " + (u.model || "")
            periph.push({
                key: "up:" + u.nativePath, name: u.model || "Устройство", glyph: cc.upGlyph(u.type),
                conn: /hidpp|receiver|wireless|2\.4|dongle|unifying|lightspeed/i.test(tag) ? "radio" : "wired",
                battery: cc.norm(u.percentage), charging: cc.isCharging(u.state),
                plugged: false, connected: true, busy: false, dev: null
            })
        }

        var bts = Bluetooth.devices ? Bluetooth.devices.values : []
        var btList = []
        for (var j = 0; j < bts.length; j++) {
            var d = bts[j]
            if (!d || !(d.paired || d.bonded || d.trusted || d.connected)) continue
            var up = upByMac[(d.address || "").toUpperCase()]
            var batt = d.batteryAvailable ? cc.norm(d.battery) : (up ? cc.norm(up.percentage) : -1)
            btList.push({
                key: "bt:" + d.address, name: d.name || d.address, glyph: cc.btGlyph(d.icon, d.name), conn: "bt",
                battery: d.connected ? batt : -1, charging: d.connected && up ? cc.isCharging(up.state) : false,
                plugged: false, connected: d.connected,
                busy: d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting || root.btConnectingMAC.toUpperCase() === (d.address || "").toUpperCase(),
                dev: d
            })
        }

        // Проводные / радио-устройства из Hyprland, которых нет в списках выше
        var known = btList.map(function(x) { return cc.slug(x.name) }).concat(periph.map(function(x) { return cc.slug(x.name) }))
        var wired = []
        for (var k = 0; k < inputGroups.length; k++) {
            var g = inputGroups[k]
            var gs = cc.slug(g.base)
            var dup = known.some(function(n) { return n.length >= 4 && (gs.indexOf(n) >= 0 || n.indexOf(gs) >= 0) })
            if (dup) continue
            wired.push({
                key: "in:" + g.base, name: g.name, glyph: g.kind === "mouse" ? "\u{F037D}" : "\u{F030C}",
                conn: g.radio ? "radio" : "wired", battery: -1, charging: false, plugged: false,
                connected: true, busy: false, dev: null
            })
        }

        btList.sort(function(x, y) { return (y.connected ? 1 : 0) - (x.connected ? 1 : 0) })
        var connectedBt = btList.filter(function(x) { return x.connected })
        var offBt = btList.filter(function(x) { return !x.connected })
        devices = list.concat(connectedBt, periph, wired, offBt)
    }

    function parseInputs(txt) {
        var data
        try { data = JSON.parse(txt) } catch (e) { return }
        var internal = /avrcp|video-bus|intel-hid|power-button|sleep-button|wmi|at-translated|touchpad|hotkeys|virtual|ydotool|lid-switch|^.*:/
        var groups = {}
        var order = []
        function add(name, kind) {
            if (internal.test(name)) return
            var base = name.replace(/(-consumer-control|-system-control|-keyboard|-mouse)?(-\d+)?$/, "")
                           .replace(/(-consumer-control|-system-control|-keyboard|-mouse)$/, "")
            if (!groups[base]) {
                groups[base] = { base: base, kinds: {}, exact: "" }
                order.push(base)
            }
            groups[base].kinds[kind] = true
            if (name === base) groups[base].exact = kind
        }
        ;(data.keyboards || []).forEach(function(d) { add(d.name, "keyboard") })
        ;(data.mice || []).forEach(function(d) { add(d.name, "mouse") })
        var out = []
        order.forEach(function(b) {
            var g = groups[b]
            var kind = g.exact || (g.kinds.keyboard ? "keyboard" : "mouse")
            var pretty = b.split("-").map(function(p) { return p.length <= 3 && /\d/.test(p) === false && p.length > 0 ? p.toUpperCase() : p.charAt(0).toUpperCase() + p.slice(1) }).join(" ")
            out.push({ base: b, name: pretty, kind: kind,
                       radio: /wireless|receiver|2-4g|dongle|unifying|lightspeed|nano/.test(b) })
        })
        inputGroups = out
        rebuildDevices()
    }

    Process {
        id: inputsProc
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector { onStreamFinished: cc.parseInputs(text) }
    }

    Connections {
        target: Bluetooth.devices
        function onValuesChanged() { cc.rebuildDevices() }
    }

    // ════════════════════════ Курсор ════════════════════════

    property var cursorThemes: []
    property bool cursorsLoaded: false
    property string cursorTheme: ""
    property int cursorSize: 24

    Process {
        id: cursorListProc
        command: ["python3", root.configPath + "/scripts/cursor-themes.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { cc.cursorThemes = JSON.parse(text); cc.cursorsLoaded = true } catch (e) {}
            }
        }
    }

    Process {
        id: cursorCurProc
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface cursor-theme; gsettings get org.gnome.desktop.interface cursor-size"]
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.trim().split("\n")
                if (l.length >= 2) {
                    cc.cursorTheme = l[0].replace(/'/g, "").trim()
                    cc.cursorSize = parseInt(l[1]) || 24
                }
            }
        }
    }

    Process { id: cursorApplyProc }

    function applyCursor(theme, size) {
        cursorTheme = theme
        cursorSize = size
        cursorApplyProc.command = ["python3", script, "cursor", JSON.stringify({ theme: theme, size: size })]
        cursorApplyProc.running = true
    }

    // ════════════════════════ Не беспокоить ════════════════════════

    property bool dnd: false
    Process {
        id: dndGetProc
        command: ["swaync-client", "-D"]
        stdout: StdioCollector { onStreamFinished: cc.dnd = text.trim() === "true" }
    }
    Process {
        id: dndToggleProc
        command: ["swaync-client", "-d"]
        stdout: StdioCollector { onStreamFinished: cc.dnd = text.trim() === "true" }
    }

    // ════════════════════════ Мониторы ════════════════════════

    property var mons: []
    property var monsOrig: []
    property string selMon: ""
    property int confirmLeft: 0          // >0 — ждём подтверждения новых настроек

    readonly property var selM: {
        for (var i = 0; i < mons.length; i++) if (mons[i].name === selMon) return mons[i]
        return mons.length ? mons[0] : null
    }
    readonly property bool monDirty: monSig(mons) !== monSig(monsOrig)

    function monSig(list) {
        return list.map(function(m) { return [m.name, m.w, m.h, m.rate, m.x, m.y, m.scale, m.transform].join(",") }).join(";")
    }
    function clone(list) { return JSON.parse(JSON.stringify(list)) }
    function lw(m) { return Math.round((m.transform % 2 ? m.h : m.w) / m.scale) }
    function lh(m) { return Math.round((m.transform % 2 ? m.w : m.h) / m.scale) }

    function loadMonitors(txt) {
        var arr
        try { arr = JSON.parse(txt) } catch (e) { return }
        var out = []
        arr.forEach(function(m) {
            var modes = []
            ;(m.availableModes || []).forEach(function(s) {
                var r = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(s)
                if (r) modes.push({ w: +r[1], h: +r[2], r: r[3] })
            })
            var rate = "" + Math.round(m.refreshRate)
            var best = 1e9
            modes.forEach(function(md) {
                if (md.w === m.width && md.h === m.height && Math.abs(+md.r - m.refreshRate) < best) {
                    best = Math.abs(+md.r - m.refreshRate); rate = md.r
                }
            })
            out.push({
                name: m.name, desc: ((m.make || "") + " " + (m.model || "")).trim() || m.description,
                w: m.width, h: m.height, rate: rate, x: m.x, y: m.y,
                scale: Math.round(m.scale * 100) / 100, transform: m.transform % 4,
                focused: m.focused, modes: modes
            })
        })
        out.sort(function(p, q) { return p.x - q.x || p.y - q.y })
        mons = out
        monsOrig = clone(out)
        if (!out.some(function(m) { return m.name === selMon })) {
            var f = out.filter(function(m) { return m.focused })
            selMon = f.length ? f[0].name : (out.length ? out[0].name : "")
        }
    }

    Process {
        id: monProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector { onStreamFinished: cc.loadMonitors(text) }
    }

    function resolutions(m) {
        var seen = {}, res = []
        if (!m) return res
        m.modes.forEach(function(md) {
            var k = md.w + "x" + md.h
            if (!seen[k]) { seen[k] = true; res.push({ w: md.w, h: md.h }) }
        })
        res.sort(function(p, q) { return q.w * q.h - p.w * p.h })
        return res
    }
    function ratesFor(m) {
        if (!m) return []
        var r = m.modes.filter(function(md) { return md.w === m.w && md.h === m.h }).map(function(md) { return md.r })
        r = r.filter(function(v, i) { return r.indexOf(v) === i })
        r.sort(function(p, q) { return +q - +p })
        return r
    }
    function fmtRate(r) { var n = +r; return (Math.abs(n - Math.round(n)) < 0.02 ? Math.round(n) : n.toFixed(2)) + " Гц" }

    function normalize(list) {
        if (!list.length) return
        var mx = Math.min.apply(null, list.map(function(m) { return m.x }))
        var my = Math.min.apply(null, list.map(function(m) { return m.y }))
        list.forEach(function(m) { m.x = Math.round(m.x - mx); m.y = Math.round(m.y - my) })
    }

    // Меняет параметры монитора и сдвигает соседей, прилегавших к его правому/нижнему краю
    function editMon(name, fn) {
        var list = clone(mons)
        var m = list.filter(function(x) { return x.name === name })[0]
        if (!m) return
        var oldW = lw(m), oldH = lh(m)
        fn(m)
        var dW = lw(m) - oldW, dH = lh(m) - oldH
        list.forEach(function(o) {
            if (o === m) return
            if (o.x >= m.x + oldW) o.x += dW
            if (o.y >= m.y + oldH) o.y += dH
        })
        normalize(list)
        mons = list
    }

    function setResolution(w, h) {
        editMon(selM.name, function(m) {
            m.w = w; m.h = h
            var rates = cc.ratesFor(m)
            if (rates.indexOf(m.rate) < 0) m.rate = rates.length ? rates[0] : "60"
        })
    }

    // Прикрепляет монитор name к краю ближайшего соседа (позиция px,py — желаемая)
    // Ближайшая позиция у края соседа: монитор «прилипает» к стороне и скользит вдоль неё,
    // магнитясь к выравниванию по верху/центру/низу. Позиции с наложением отбрасываются.
    function computeSnap(name, px, py, forcedSide) {
        var m = mons.filter(function(x) { return x.name === name })[0]
        var others = mons.filter(function(x) { return x.name !== name })
        if (!m || !others.length) return null
        var W = lw(m), H = lh(m)
        function slide(v, lo, hi, marks, mag) {
            v = Math.max(lo, Math.min(hi, v))
            for (var i = 0; i < marks.length; i++) if (Math.abs(v - marks[i]) < mag) return marks[i]
            return Math.round(v)
        }
        function overlaps(x, y) {
            return others.some(function(o) {
                return x < o.x + lw(o) - 1 && x + W > o.x + 1 && y < o.y + lh(o) - 1 && y + H > o.y + 1
            })
        }
        var best = null
        others.forEach(function(o) {
            var ow = lw(o), oh = lh(o)
            var ys = slide(py, o.y - H + 100, o.y + oh - 100, [o.y, o.y + (oh - H) / 2, o.y + oh - H], oh * 0.08)
            var xs = slide(px, o.x - W + 100, o.x + ow - 100, [o.x, o.x + (ow - W) / 2, o.x + ow - W], ow * 0.08)
            ;[{ side: "right", x: o.x + ow, y: ys }, { side: "left", x: o.x - W, y: ys },
              { side: "below", x: xs, y: o.y + oh }, { side: "above", x: xs, y: o.y - H }].forEach(function(c) {
                if (forcedSide && c.side !== forcedSide) return
                if (overlaps(c.x, c.y)) return
                var d = Math.hypot(c.x - px, c.y - py)
                if (!best || d < best.d) best = { x: Math.round(c.x), y: Math.round(c.y), d: d }
            })
        })
        return best
    }

    function snapPlace(name, px, py, forcedSide) {
        var best = computeSnap(name, px, py, forcedSide)
        if (!best) return
        var list = clone(mons)
        list.forEach(function(x) { if (x.name === name) { x.x = best.x; x.y = best.y } })
        normalize(list)
        mons = list
    }

    function placeRelative(side) {
        var o = mons.filter(function(x) { return x.name !== selM.name })[0]
        if (!o) return
        var px = side === "left" ? o.x - lw(selM) : side === "right" ? o.x + lw(o) : o.x
        var py = side === "above" ? o.y - lh(selM) : side === "below" ? o.y + lh(o) : o.y
        snapPlace(selM.name, px, py, side)
    }

    function monLua(m) {
        return 'hl.monitor({output="' + m.name + '", mode="' + m.w + 'x' + m.h + '@' + m.rate +
               '", position="' + m.x + 'x' + m.y + '", scale=' + m.scale + ', transform=' + m.transform + '})'
    }
    function pushMonitors(list) {
        monApplyProc.command = ["hyprctl", "eval", "(function() " + list.map(monLua).join(" ") + " end)()"]
        monApplyProc.running = true
    }

    Process {
        id: monApplyProc
        stdout: StdioCollector { onStreamFinished: if (text.trim() !== "ok" && text.trim() !== "") console.warn("monitors:", text) }
    }
    Process { id: monSaveProc; onExited: if (!monProc.running) monProc.running = true }

    function applyMonitors() {
        pushMonitors(mons)
        confirmLeft = 15
    }
    function keepMonitors() {
        confirmLeft = 0
        var payload = mons.map(function(m) {
            return { output: m.name, mode: m.w + "x" + m.h + "@" + m.rate, position: m.x + "x" + m.y,
                     scale: m.scale, transform: m.transform }
        })
        monsOrig = clone(mons)
        monSaveProc.command = ["python3", script, "monitors", JSON.stringify(payload)]
        monSaveProc.running = true
    }
    function revertMonitors() {
        confirmLeft = 0
        pushMonitors(monsOrig)
        mons = clone(monsOrig)
    }

    Timer {
        interval: 1000
        repeat: true
        running: cc.confirmLeft > 0
        onTriggered: {
            cc.confirmLeft -= 1
            if (cc.confirmLeft <= 0) cc.revertMonitors()
        }
    }

    // ════════════════════════ Общие элементы ════════════════════════

    component SectionTitle: RowLayout {
        property alias text: lbl.text
        property alias glyph: ic.text
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8
        Text { id: ic; color: root.walColor5; font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font" }
        Text { id: lbl; color: root.walForeground; font.pixelSize: 13; font.bold: true; font.family: "JetBrainsMono Nerd Font" }
        Item { Layout.fillWidth: true }
    }

    component Chip: Rectangle {
        id: chip
        property string label: ""
        property bool on: false
        property color accent: root.walColor5
        signal clicked()
        implicitHeight: 28
        implicitWidth: chipText.implicitWidth + 20
        radius: 8
        color: on ? Qt.rgba(accent.r, accent.g, accent.b, 0.22) : (chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.25))
        border.width: on ? 1 : 0
        border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.6)
        Behavior on color { ColorAnimation { duration: 120 } }
        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.on ? chip.accent : root.walForeground
            font.pixelSize: 11
            font.bold: chip.on
            font.family: "JetBrainsMono Nerd Font"
        }
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    component QuickToggle: Rectangle {
        id: qt
        property string glyph: ""
        property string label: ""
        property string sub: ""
        property bool on: false
        property color accent: root.walColor5
        signal clicked()
        implicitHeight: 84
        radius: 16
        color: on ? Qt.rgba(accent.r, accent.g, accent.b, 0.25) : (qtMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.3))
        Behavior on color { ColorAnimation { duration: 150 } }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 11
            spacing: 2
            Rectangle {
                width: 34; height: 34; radius: 17
                color: qt.on ? qt.accent : Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: qt.glyph
                    color: qt.on ? root.walBackground : root.walForeground
                    font.pixelSize: 18
                    font.family: "JetBrainsMono Nerd Font"
                }
            }
            Item { Layout.fillHeight: true }
            Text {
                Layout.fillWidth: true
                text: qt.label
                color: root.walForeground
                font.pixelSize: 12
                font.bold: true
                font.family: "JetBrainsMono Nerd Font"
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: qt.sub
                color: root.walColor8
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
                elide: Text.ElideRight
            }
        }
        MouseArea {
            id: qtMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: qt.clicked()
        }
    }

    // Кольцо заряда в стиле виджета iOS: разрыв снизу под процент
    component BatteryRing: Canvas {
        id: ring
        property real value: -1
        property color fg: root.walColor5
        property color track: Qt.rgba(1, 1, 1, 0.12)
        property real gapDeg: 80
        property real line: 4
        Behavior on value { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
        onValueChanged: requestPaint()
        onFgChanged: requestPaint()
        onTrackChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var r = Math.min(width, height) / 2 - line / 2 - 1
            var gap = gapDeg * Math.PI / 180
            var start = Math.PI / 2 + gap / 2
            var sweep = 2 * Math.PI - gap
            ctx.lineCap = "round"
            ctx.lineWidth = line
            ctx.strokeStyle = track
            ctx.beginPath()
            ctx.arc(width / 2, height / 2, r, start, start + sweep, false)
            ctx.stroke()
            if (value > 0.005) {
                ctx.strokeStyle = fg
                ctx.beginPath()
                ctx.arc(width / 2, height / 2, r, start, start + sweep * Math.min(1, value), false)
                ctx.stroke()
            }
        }
    }

    // ════════════════════════ Разметка ════════════════════════

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight + 10
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: !layoutArea.dragging
        ScrollBar.vertical: ScrollBar { width: 4; policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: col
            width: flick.width - 2
            spacing: 12

            // ─── Быстрые переключатели ───
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                QuickToggle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    glyph: root.wifiEnabled ? "\u{F05A9}" : "\u{F05AA}"
                    label: "Wi-Fi"
                    sub: root.wifiEnabled ? (root.wifiCurrentSSID || "Вкл.") : "Выкл."
                    on: root.wifiEnabled
                    onClicked: wifiToggleProc.running = true
                }
                QuickToggle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    readonly property var ad: Bluetooth.defaultAdapter
                    glyph: ad && ad.enabled ? "\u{F00AF}" : "\u{F00B2}"
                    label: "Bluetooth"
                    sub: ad && ad.enabled ? cc.devices.filter(function(d) { return d.conn === "bt" && d.connected }).length + " подкл." : "Выкл."
                    on: !!(ad && ad.enabled)
                    onClicked: if (ad) ad.enabled = !ad.enabled
                }
                QuickToggle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    glyph: "\u{F0594}"
                    label: "Тишина"
                    sub: cc.dnd ? "Вкл." : "Выкл."
                    on: cc.dnd
                    accent: root.walColor13
                    onClicked: dndToggleProc.running = true
                }
                QuickToggle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    readonly property var order: ["power-saver", "balanced", "performance"]
                    glyph: root.activePowerProfile === "power-saver" ? "\u{F032A}" : root.activePowerProfile === "performance" ? "\u{F04C5}" : "\u{F05D1}"
                    label: "Режим"
                    sub: root.activePowerProfile === "power-saver" ? "Эконом" : root.activePowerProfile === "performance" ? "Мощность" : "Баланс"
                    on: root.activePowerProfile !== "balanced"
                    accent: root.activePowerProfile === "power-saver" ? root.walColor2 : root.walColor1
                    onClicked: {
                        var i = order.indexOf(root.activePowerProfile)
                        root.activePowerProfile = order[(i + 1) % order.length]
                        root.setPowerProfile(root.activePowerProfile)
                    }
                }
            }

            // ─── Устройства ───
            SectionTitle {
                glyph: "\u{F00AF}"
                text: "Устройства"
                Text {
                    text: "ПКМ — забыть"
                    color: root.walColor8
                    font.pixelSize: 9
                    font.family: "JetBrainsMono Nerd Font"
                    opacity: 0.7
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: devGrid.implicitHeight + 24
                color: Qt.rgba(0, 0, 0, 0.3)
                radius: 16

                Grid {
                    id: devGrid
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    columns: 4
                    spacing: 10
                    readonly property real tile: (width - spacing * (columns - 1)) / columns

                    Repeater {
                        model: cc.devices
                        delegate: Item {
                            id: devItem
                            required property var modelData
                            readonly property var d: modelData
                            readonly property bool low: d.battery >= 0 && d.battery < 0.2 && !d.charging
                            readonly property color ringColor: d.charging ? root.walColor2 : low ? root.walColor1 : root.walColor5
                            width: devGrid.tile
                            height: devGrid.tile + 18

                            Rectangle {
                                id: tile
                                width: devGrid.tile
                                height: devGrid.tile
                                radius: 18
                                color: tileMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                                border.width: devItem.d.connected ? 1 : 0
                                border.color: Qt.rgba(devItem.ringColor.r, devItem.ringColor.g, devItem.ringColor.b, 0.25)
                                opacity: devItem.d.connected ? 1 : 0.5
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                                Behavior on color { ColorAnimation { duration: 120 } }

                                BatteryRing {
                                    id: ringC
                                    anchors.fill: parent
                                    anchors.margins: 7
                                    value: devItem.d.battery
                                    fg: devItem.ringColor
                                    line: 4
                                    visible: devItem.d.battery >= 0 || devItem.d.conn === "bt"
                                }
                                // мягкое «дыхание» кольца во время зарядки
                                BatteryRing {
                                    anchors.fill: ringC
                                    value: devItem.d.battery
                                    fg: root.walColor2
                                    track: "transparent"
                                    line: 8
                                    visible: devItem.d.charging
                                    SequentialAnimation on opacity {
                                        running: devItem.d.charging
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.0; to: 0.35; duration: 1100; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 0.35; to: 0.0; duration: 1100; easing.type: Easing.InOutSine }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -3
                                    text: devItem.d.glyph
                                    color: devItem.d.connected ? root.walForeground : root.walColor8
                                    font.pixelSize: devGrid.tile * 0.3
                                    font.family: "JetBrainsMono Nerd Font"
                                }

                                // процент в разрыве кольца
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 4
                                    spacing: 1
                                    Text {
                                        visible: devItem.d.charging || devItem.d.plugged
                                        text: devItem.d.charging ? "\u{F140B}" : "\u{F06A5}"
                                        color: devItem.d.charging ? root.walColor2 : root.walColor8
                                        font.pixelSize: 10
                                        font.family: "JetBrainsMono Nerd Font"
                                        SequentialAnimation on opacity {
                                            running: devItem.d.charging
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 0.35; duration: 800 }
                                            NumberAnimation { to: 1.0; duration: 800 }
                                        }
                                    }
                                    Text {
                                        text: devItem.d.battery >= 0 ? Math.round(devItem.d.battery * 100) + "%"
                                              : devItem.d.conn === "bt" ? (devItem.d.connected ? "—" : "откл")
                                              : devItem.d.conn === "radio" ? "2.4G" : "USB"
                                        color: devItem.d.battery >= 0 ? devItem.ringColor : root.walColor8
                                        font.pixelSize: 9
                                        font.bold: devItem.d.battery >= 0
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                }

                                // тип подключения
                                Rectangle {
                                    visible: devItem.d.conn !== "internal"
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: -3
                                    width: 18; height: 18; radius: 9
                                    color: root.walBackground
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.12)
                                    Text {
                                        anchors.centerIn: parent
                                        text: devItem.d.conn === "bt" ? "\u{F00AF}" : devItem.d.conn === "radio" ? "\u{F0003}" : "\u{F0553}"
                                        color: devItem.d.conn === "bt" ? root.walColor5 : devItem.d.conn === "radio" ? root.walColor13 : root.walColor4
                                        font.pixelSize: 10
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                }

                                // подключение / отключение в процессе
                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: Qt.rgba(0, 0, 0, 0.35)
                                    visible: devItem.d.busy
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\u{F0450}"
                                        color: root.walColor5
                                        font.pixelSize: 18
                                        font.family: "JetBrainsMono Nerd Font"
                                        RotationAnimation on rotation { running: devItem.d.busy; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                                    }
                                }

                                MouseArea {
                                    id: tileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: devItem.d.dev ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: function(mouse) {
                                        var dev = devItem.d.dev
                                        if (!dev) return
                                        if (mouse.button === Qt.RightButton) { cc.menuKey = devItem.d.key; return }
                                        if (dev.connected) root.disconnectBt(dev.address)
                                        else root.connectBt(dev.address)
                                    }
                                }

                                // меню «Забыть»
                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    visible: cc.menuKey === devItem.d.key
                                    color: Qt.rgba(root.walBackground.r, root.walBackground.g, root.walBackground.b, 0.95)
                                    border.width: 1
                                    border.color: root.walColor1
                                    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: cc.menuKey = "" }
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Rectangle {
                                            width: devGrid.tile - 14; height: 24; radius: 8
                                            color: forgetMouse.containsMouse ? Qt.rgba(root.walColor1.r, root.walColor1.g, root.walColor1.b, 0.35) : Qt.rgba(root.walColor1.r, root.walColor1.g, root.walColor1.b, 0.18)
                                            Text { anchors.centerIn: parent; text: "\u{F01B4} Забыть"; color: root.walColor1; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                                            MouseArea {
                                                id: forgetMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: { if (devItem.d.dev) root.forgetBt(devItem.d.dev.address); cc.menuKey = "" }
                                            }
                                        }
                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "отмена"; color: root.walColor8; font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font" }
                                    }
                                }
                            }

                            Text {
                                anchors.top: tile.bottom
                                anchors.topMargin: 4
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                readonly property bool hasStatus: !!devItem.d.dev && root.btStatusMAC.toUpperCase() === (devItem.d.dev.address || "").toUpperCase() && root.btStatusCode !== ""
                                text: hasStatus ? ({ connecting: "подключение…", pairing: "сопряжение…", waiting: "ждём…", ok: "готово", fail: "ошибка" })[root.btStatusCode] || devItem.d.name : devItem.d.name
                                color: hasStatus ? (root.btStatusCode === "fail" ? root.walColor1 : root.btStatusCode === "ok" ? root.walColor2 : root.walColor4)
                                       : devItem.d.connected ? root.walForeground : root.walColor8
                                font.pixelSize: 9
                                font.family: "JetBrainsMono Nerd Font"
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // «Добавить» — открывает панель поиска Bluetooth
                    Item {
                        width: devGrid.tile
                        height: devGrid.tile + 18
                        Rectangle {
                            id: addTile
                            width: devGrid.tile
                            height: devGrid.tile
                            radius: 18
                            color: addMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            Text {
                                anchors.centerIn: parent
                                text: "\u{F0415}"
                                color: root.walColor8
                                font.pixelSize: devGrid.tile * 0.28
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            MouseArea {
                                id: addMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (!root.btVisible) root.toggleBluetooth()
                            }
                        }
                        Text {
                            anchors.top: addTile.bottom
                            anchors.topMargin: 4
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "Добавить"
                            color: root.walColor8
                            font.pixelSize: 9
                            font.family: "JetBrainsMono Nerd Font"
                        }
                    }
                }
            }

            // Состояние подключения Bluetooth (пояснения скрипта: «включите режим сопряжения» и т.п.)
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: -4
                Layout.preferredHeight: btStatusLbl.implicitHeight + 14
                visible: root.btStatusText !== ""
                radius: 10
                readonly property color tone: root.btStatusCode === "fail" ? root.walColor1 : root.btStatusCode === "ok" ? root.walColor2 : root.walColor4
                color: Qt.rgba(tone.r, tone.g, tone.b, 0.12)
                border.width: 1
                border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.4)
                Text {
                    id: btStatusLbl
                    anchors.fill: parent
                    anchors.margins: 7
                    verticalAlignment: Text.AlignVCenter
                    text: "\u{F00AF}  " + root.btStatusText
                    color: parent.tone
                    font.pixelSize: 11
                    font.family: "JetBrainsMono Nerd Font"
                    wrapMode: Text.WordWrap
                }
            }

            // ─── Мониторы ───
            SectionTitle {
                glyph: "\u{F0379}"
                text: "Мониторы"
                Text {
                    text: "\u{F0450}"
                    color: root.walColor8
                    font.pixelSize: 13
                    font.family: "JetBrainsMono Nerd Font"
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (cc.confirmLeft === 0 && !monProc.running) monProc.running = true }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: monCol.implicitHeight + 24
                color: Qt.rgba(0, 0, 0, 0.3)
                radius: 16

                ColumnLayout {
                    id: monCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    // Схема расположения — мониторы можно перетаскивать
                    Rectangle {
                        id: layoutArea
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        radius: 12
                        color: Qt.rgba(0, 0, 0, 0.25)
                        clip: true

                        property string dragName: ""
                        property real dragX: 0          // позиция перетаскиваемого монитора (в пикселях экрана)
                        property real dragY: 0
                        property var ghost: null        // куда он встанет после отпускания
                        readonly property bool dragging: dragName !== ""
                        property var view: ({ s: 0.05, ox: 0, oy: 0 })

                        function recompute() {
                            if (dragging || !cc.mons.length) return
                            var minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9
                            cc.mons.forEach(function(m) {
                                minX = Math.min(minX, m.x); minY = Math.min(minY, m.y)
                                maxX = Math.max(maxX, m.x + cc.lw(m)); maxY = Math.max(maxY, m.y + cc.lh(m))
                            })
                            // запас по краям, чтобы монитор можно было поставить сверху/сбоку
                            var pad = Math.max(maxX - minX, maxY - minY) * 0.1
                            minX -= pad; minY -= pad; maxX += pad; maxY += pad
                            var bw = maxX - minX, bh = maxY - minY
                            var s = Math.min((width - 16) / bw, (height - 16) / bh)
                            view = { s: s, ox: (width - bw * s) / 2 - minX * s, oy: (height - bh * s) / 2 - minY * s }
                        }
                        onWidthChanged: recompute()
                        onDraggingChanged: recompute()
                        Connections { target: cc; function onMonsChanged() { layoutArea.recompute() } }

                        // колесо над схемой не прокручивает панель
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: function(w) { w.accepted = true }
                        }

                        Text {
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.margins: 6
                            text: "перетащите"
                            color: root.walColor8
                            font.pixelSize: 8
                            font.family: "JetBrainsMono Nerd Font"
                            opacity: 0.6
                            visible: cc.mons.length > 1
                        }

                        // «призрак» — место, куда встанет монитор
                        Rectangle {
                            visible: layoutArea.dragging && !!layoutArea.ghost
                            readonly property var gm: cc.mons.filter(function(x) { return x.name === layoutArea.dragName })[0]
                            x: layoutArea.ghost ? layoutArea.view.ox + layoutArea.ghost.x * layoutArea.view.s : 0
                            y: layoutArea.ghost ? layoutArea.view.oy + layoutArea.ghost.y * layoutArea.view.s : 0
                            width: gm ? cc.lw(gm) * layoutArea.view.s - 3 : 0
                            height: gm ? cc.lh(gm) * layoutArea.view.s - 3 : 0
                            radius: 6
                            color: Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.12)
                            border.width: 1
                            border.color: root.walColor5
                            Behavior on x { NumberAnimation { duration: 90 } }
                            Behavior on y { NumberAnimation { duration: 90 } }
                        }

                        Repeater {
                            model: cc.mons
                            delegate: Rectangle {
                                id: monRect
                                required property var modelData
                                readonly property bool sel: cc.selM && cc.selM.name === modelData.name
                                readonly property bool held: layoutArea.dragName === modelData.name
                                x: layoutArea.view.ox + (held ? layoutArea.dragX : modelData.x) * layoutArea.view.s
                                y: layoutArea.view.oy + (held ? layoutArea.dragY : modelData.y) * layoutArea.view.s
                                width: cc.lw(modelData) * layoutArea.view.s - 3
                                height: cc.lh(modelData) * layoutArea.view.s - 3
                                radius: 6
                                z: held ? 10 : 1
                                opacity: held ? 0.85 : 1
                                color: sel ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.3) : Qt.rgba(0.2, 0.2, 0.2, 0.9)
                                border.width: sel ? 2 : 1
                                border.color: sel ? root.walColor5 : Qt.rgba(1, 1, 1, 0.2)

                                // полоска — «верх» экрана (видно поворот)
                                Rectangle {
                                    readonly property int t: monRect.modelData.transform
                                    color: monRect.sel ? root.walColor5 : root.walColor8
                                    opacity: 0.8
                                    radius: 1
                                    width: t % 2 ? 2 : parent.width * 0.4
                                    height: t % 2 ? parent.height * 0.4 : 2
                                    x: t === 1 ? 4 : t === 3 ? parent.width - 6 : (parent.width - width) / 2
                                    y: t === 0 ? 4 : t === 2 ? parent.height - 6 : (parent.height - height) / 2
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 1
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: monRect.modelData.name
                                        color: monRect.sel ? root.walColor5 : root.walForeground
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: monRect.modelData.w + "×" + monRect.modelData.h
                                        color: root.walColor8
                                        font.pixelSize: 8
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                }

                                MouseArea {
                                    id: monMouse
                                    anchors.fill: parent
                                    preventStealing: true
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    property point start
                                    property real baseX
                                    property real baseY
                                    function finish(commit) {
                                        var name = layoutArea.dragName
                                        var g = layoutArea.ghost
                                        layoutArea.ghost = null
                                        layoutArea.dragName = ""
                                        if (commit && g) cc.snapPlace(name, g.x, g.y, "")
                                    }
                                    onPressed: function(m) {
                                        cc.selMon = monRect.modelData.name
                                        start = mapToItem(layoutArea, m.x, m.y)
                                        baseX = monRect.modelData.x
                                        baseY = monRect.modelData.y
                                        layoutArea.dragX = baseX
                                        layoutArea.dragY = baseY
                                        layoutArea.ghost = null
                                    }
                                    onPositionChanged: function(m) {
                                        var p = mapToItem(layoutArea, m.x, m.y)
                                        if (!layoutArea.dragging) {
                                            if (Math.abs(p.x - start.x) + Math.abs(p.y - start.y) < 4 || cc.mons.length < 2) return
                                            layoutArea.dragName = monRect.modelData.name
                                        }
                                        var s = layoutArea.view.s
                                        layoutArea.dragX = baseX + (p.x - start.x) / s
                                        layoutArea.dragY = baseY + (p.y - start.y) / s
                                        layoutArea.ghost = cc.computeSnap(layoutArea.dragName, layoutArea.dragX, layoutArea.dragY, "")
                                    }
                                    onReleased: finish(true)
                                    onCanceled: finish(false)
                                }
                            }
                        }
                    }

                    // Быстрое расположение относительно второго монитора
                    RowLayout {
                        Layout.fillWidth: true
                        visible: cc.mons.length > 1
                        spacing: 6
                        Text {
                            text: "Поставить:"
                            color: root.walColor8
                            font.pixelSize: 10
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        Chip { Layout.fillWidth: true; label: "← слева"; onClicked: cc.placeRelative("left") }
                        Chip { Layout.fillWidth: true; label: "справа →"; onClicked: cc.placeRelative("right") }
                        Chip { Layout.fillWidth: true; label: "↑"; onClicked: cc.placeRelative("above") }
                        Chip { Layout.fillWidth: true; label: "↓"; onClicked: cc.placeRelative("below") }
                    }

                    // Выбор монитора
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: cc.mons.length > 1
                        Repeater {
                            model: cc.mons
                            delegate: Chip {
                                required property var modelData
                                Layout.fillWidth: true
                                label: modelData.name
                                on: cc.selM && cc.selM.name === modelData.name
                                onClicked: cc.selMon = modelData.name
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: !!cc.selM
                        text: cc.selM ? cc.selM.desc : ""
                        color: root.walColor8
                        font.pixelSize: 9
                        font.family: "JetBrainsMono Nerd Font"
                        elide: Text.ElideRight
                    }

                    // Разрешение
                    RowLayout {
                        Layout.fillWidth: true
                        visible: !!cc.selM
                        spacing: 8
                        readonly property var res: cc.resolutions(cc.selM)
                        readonly property int idx: {
                            if (!cc.selM) return -1
                            for (var i = 0; i < res.length; i++) if (res[i].w === cc.selM.w && res[i].h === cc.selM.h) return i
                            return -1
                        }
                        Text {
                            Layout.preferredWidth: 78
                            text: "Разрешение"
                            color: root.walForeground
                            font.pixelSize: 11
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        Chip {
                            label: "‹"
                            opacity: parent.idx < parent.res.length - 1 ? 1 : 0.3
                            onClicked: { var r = parent.res[parent.idx + 1]; if (r) cc.setResolution(r.w, r.h) }
                        }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: cc.selM ? cc.selM.w + " × " + cc.selM.h + (parent.idx === 0 ? "  (макс)" : "") : ""
                            color: root.walColor5
                            font.pixelSize: 12
                            font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        Chip {
                            label: "›"
                            opacity: parent.idx > 0 ? 1 : 0.3
                            onClicked: { var r = parent.res[parent.idx - 1]; if (r) cc.setResolution(r.w, r.h) }
                        }
                    }

                    // Частота
                    RowLayout {
                        Layout.fillWidth: true
                        visible: !!cc.selM
                        spacing: 8
                        Text {
                            Layout.preferredWidth: 78
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 6
                            text: "Частота"
                            color: root.walForeground
                            font.pixelSize: 11
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: cc.ratesFor(cc.selM)
                                delegate: Chip {
                                    required property var modelData
                                    label: cc.fmtRate(modelData)
                                    on: cc.selM && cc.selM.rate === modelData
                                    onClicked: { var r = modelData; cc.editMon(cc.selM.name, function(m) { m.rate = r }) }
                                }
                            }
                        }
                    }

                    // Ориентация
                    RowLayout {
                        Layout.fillWidth: true
                        visible: !!cc.selM
                        spacing: 6
                        Repeater {
                            model: [
                                { t: 0, label: "Гориз." },
                                { t: 1, label: "Верт." },
                                { t: 2, label: "Перевёрн." },
                                { t: 3, label: "Верт. ↺" }
                            ]
                            delegate: Rectangle {
                                id: oriBtn
                                required property var modelData
                                readonly property bool on: cc.selM && cc.selM.transform === modelData.t
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                                radius: 10
                                color: on ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.22) : (oriMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.25))
                                border.width: on ? 1 : 0
                                border.color: root.walColor5
                                Rectangle {
                                    id: miniScreen
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 8
                                    readonly property bool portrait: oriBtn.modelData.t % 2 === 1
                                    width: portrait ? 14 : 24
                                    height: portrait ? 22 : 14
                                    radius: 2
                                    color: "transparent"
                                    border.width: 1.5
                                    border.color: oriBtn.on ? root.walColor5 : root.walColor8
                                    // «верх» экрана
                                    Rectangle {
                                        readonly property int t: oriBtn.modelData.t
                                        color: oriBtn.on ? root.walColor5 : root.walColor8
                                        width: t % 2 ? 3 : parent.width - 6
                                        height: t % 2 ? parent.height - 6 : 3
                                        x: t === 1 ? 2 : t === 3 ? parent.width - 5 : 3
                                        y: t === 0 ? 2 : t === 2 ? parent.height - 5 : 3
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 5
                                    text: oriBtn.modelData.label
                                    color: oriBtn.on ? root.walColor5 : root.walForeground
                                    font.pixelSize: 9
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                                MouseArea {
                                    id: oriMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { var t = oriBtn.modelData.t; cc.editMon(cc.selM.name, function(m) { m.transform = t }) }
                                }
                            }
                        }
                    }

                    // Масштаб
                    RowLayout {
                        Layout.fillWidth: true
                        visible: !!cc.selM
                        spacing: 6
                        Text {
                            Layout.preferredWidth: 78
                            text: "Масштаб"
                            color: root.walForeground
                            font.pixelSize: 11
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        Repeater {
                            model: [1, 1.25, 1.5, 2]
                            delegate: Chip {
                                required property var modelData
                                Layout.fillWidth: true
                                label: modelData + "×"
                                on: cc.selM && Math.abs(cc.selM.scale - modelData) < 0.01
                                onClicked: { var s = modelData; cc.editMon(cc.selM.name, function(m) { m.scale = s }) }
                            }
                        }
                    }

                    // Применить / подтверждение
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: cc.confirmLeft === 0
                        Chip {
                            Layout.fillWidth: true
                            label: "Сбросить"
                            opacity: cc.monDirty ? 1 : 0.4
                            onClicked: if (cc.monDirty) cc.mons = cc.clone(cc.monsOrig)
                        }
                        Chip {
                            Layout.fillWidth: true
                            label: "\u{F012C} Применить"
                            on: cc.monDirty
                            opacity: cc.monDirty ? 1 : 0.4
                            onClicked: if (cc.monDirty) cc.applyMonitors()
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: confirmCol.implicitHeight + 16
                        visible: cc.confirmLeft > 0
                        radius: 10
                        color: Qt.rgba(root.walColor4.r, root.walColor4.g, root.walColor4.b, 0.12)
                        border.width: 1
                        border.color: Qt.rgba(root.walColor4.r, root.walColor4.g, root.walColor4.b, 0.5)
                        ColumnLayout {
                            id: confirmCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 8
                            spacing: 6
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: "Оставить эти настройки? Откат через " + cc.confirmLeft + " с"
                                color: root.walColor4
                                font.pixelSize: 11
                                font.family: "JetBrainsMono Nerd Font"
                                wrapMode: Text.WordWrap
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Chip { Layout.fillWidth: true; label: "Вернуть"; accent: root.walColor1; onClicked: cc.revertMonitors() }
                                Chip { Layout.fillWidth: true; label: "Оставить"; on: true; accent: root.walColor2; onClicked: cc.keepMonitors() }
                            }
                        }
                    }
                }
            }

            // ─── Курсор ───
            SectionTitle { glyph: "\u{F01BF}"; text: "Курсор" }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: curCol.implicitHeight + 24
                color: Qt.rgba(0, 0, 0, 0.3)
                radius: 16

                ColumnLayout {
                    id: curCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            Layout.preferredWidth: 60
                            text: "Размер"
                            color: root.walForeground
                            font.pixelSize: 11
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        Repeater {
                            model: [16, 24, 32, 40, 48]
                            delegate: Chip {
                                required property var modelData
                                Layout.fillWidth: true
                                label: "" + modelData
                                on: cc.cursorSize === modelData
                                onClicked: cc.applyCursor(cc.cursorTheme, modelData)
                            }
                        }
                    }

                    // Свой размер: ползунок 8–128 + точная подстройка ±1 и ввод числа
                    RowLayout {
                        id: sizeRow
                        Layout.fillWidth: true
                        spacing: 8
                        property int pending: cc.cursorSize
                        Connections { target: cc; function onCursorSizeChanged() { sizeRow.pending = cc.cursorSize } }
                        function commit(v) {
                            v = Math.max(8, Math.min(128, Math.round(v)))
                            pending = v
                            if (v !== cc.cursorSize) cc.applyCursor(cc.cursorTheme, v)
                        }
                        Text {
                            Layout.preferredWidth: 60
                            text: "Свой"
                            color: root.walForeground
                            font.pixelSize: 11
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        Chip { label: "−"; onClicked: sizeRow.commit(sizeRow.pending - 1) }
                        Item {
                            id: sizeTrack
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            readonly property real f: (sizeRow.pending - 8) / 120
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 5; radius: 3
                                color: Qt.rgba(1, 1, 1, 0.1)
                                Rectangle { width: parent.width * sizeTrack.f; height: parent.height; radius: 3; color: root.walColor5 }
                            }
                            Rectangle {
                                x: sizeTrack.width * sizeTrack.f - width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14; height: 14; radius: 7
                                color: root.walForeground
                            }
                            MouseArea {
                                anchors.fill: parent
                                preventStealing: true
                                cursorShape: Qt.PointingHandCursor
                                function at(x) { return 8 + Math.max(0, Math.min(1, x / width)) * 120 }
                                onPressed: function(m) { sizeRow.pending = Math.round(at(m.x)) }
                                onPositionChanged: function(m) { if (pressed) sizeRow.pending = Math.round(at(m.x)) }
                                onReleased: sizeRow.commit(sizeRow.pending)
                                onWheel: function(w) { sizeRow.commit(sizeRow.pending + (w.angleDelta.y > 0 ? 1 : -1)) }
                            }
                        }
                        Chip { label: "+"; onClicked: sizeRow.commit(sizeRow.pending + 1) }
                        Rectangle {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 28
                            radius: 8
                            color: Qt.rgba(0, 0, 0, 0.25)
                            border.width: sizeInput.activeFocus ? 1 : 0
                            border.color: root.walColor5
                            TextInput {
                                id: sizeInput
                                anchors.fill: parent
                                horizontalAlignment: TextInput.AlignHCenter
                                verticalAlignment: TextInput.AlignVCenter
                                text: "" + sizeRow.pending
                                color: root.walColor5
                                font.pixelSize: 12
                                font.bold: true
                                font.family: "JetBrainsMono Nerd Font"
                                validator: IntValidator { bottom: 1; top: 999 }
                                selectByMouse: true
                                onAccepted: { sizeRow.commit(parseInt(text) || cc.cursorSize); cc.forceActiveFocus() }
                            }
                        }
                    }

                    Text {
                        visible: !cc.cursorsLoaded
                        text: "Загрузка тем…"
                        color: root.walColor8
                        font.pixelSize: 11
                        font.family: "JetBrainsMono Nerd Font"
                    }

                    Grid {
                        id: curGrid
                        Layout.fillWidth: true
                        columns: 2
                        spacing: 8
                        readonly property real cw: (width - spacing) / 2
                        Repeater {
                            model: cc.cursorThemes
                            delegate: Rectangle {
                                id: curCard
                                required property var modelData
                                readonly property bool on: cc.cursorTheme === modelData.name
                                width: curGrid.cw
                                height: 62
                                radius: 12
                                color: on ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.18) : (curMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03))
                                border.width: on ? 1 : 0
                                border.color: root.walColor5
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 8
                                    spacing: 8
                                    Repeater {
                                        model: curCard.modelData.previews
                                        delegate: Image {
                                            required property var modelData
                                            width: 24; height: 24
                                            source: "file://" + modelData
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            asynchronous: true
                                        }
                                    }
                                }
                                Text {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 7
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    horizontalAlignment: Text.AlignHCenter
                                    text: (curCard.on ? "\u{F012C} " : "") + curCard.modelData.name
                                    color: curCard.on ? root.walColor5 : root.walForeground
                                    font.pixelSize: 9
                                    font.bold: curCard.on
                                    font.family: "JetBrainsMono Nerd Font"
                                    elide: Text.ElideRight
                                }
                                MouseArea {
                                    id: curMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: cc.applyCursor(curCard.modelData.name, cc.cursorSize)
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 4 }
        }
    }
}
