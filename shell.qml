import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "./components"

ShellRoot {
    id: root

    property string configPath: Quickshell.env("HOME") + "/.config/quickshell"
    property string homePath: Quickshell.env("HOME")
    property string wallpaperPath: homePath + "/wallpapers"
    property string cachePath: homePath + "/.cache"
    property string statePath: configPath + "/state"

    property bool powerVisible: false
    property string activePowerProfile: "balanced"

    property bool dashboardVisible: false
    property bool musicVisible: false
    property var musicScreen: null
    // Монитор, на котором открываются боковые панели (лаунчер, Wi-Fi, BT, питание, дашборд)
    property var panelScreen: null
    function screenFor(scr) {
        if (scr) return scr
        var fm = Hyprland.focusedMonitor
        var list = Quickshell.screens
        for (var i = 0; i < list.length; i++) if (fm && list[i].name === fm.name) return list[i]
        return list.length ? list[0] : null
    }
    // Общая логика: открыта на другом мониторе — переносим туда, иначе переключаем
    function panelToggle(isOpen, scr) {
        var s = screenFor(scr)
        if (isOpen && panelScreen !== s) { panelScreen = s; return true }
        if (!isOpen) panelScreen = s
        return !isOpen
    }
    property bool launcherVisible: false
    property bool wifiVisible: false
    property bool btVisible: false
    property var pfpFiles: []
    property string searchTerm: ""
    property var appList: []
    property var appUsage: ({})
    property var filteredApps: {
        var source = appList
        var usage = appUsage
        if (searchTerm !== "") {
            var result = []
            for (var i = 0; i < source.length; i++) {
                var entry = source[i]
                if (entry.name.toLowerCase().includes(searchTerm) || entry.exec.toLowerCase().includes(searchTerm)) {
                    result.push(entry)
                }
            }
            source = result
        }
        var sorted = source.slice().sort(function(a, b) {
            var countA = usage[a.name] || 0
            var countB = usage[b.name] || 0
            if (countB !== countA) return countB - countA
            return a.name.localeCompare(b.name)
        })
        return sorted
    }
    property int selectedIndex: 0
    property int activeTab: 3
    property string wallSearchTerm: ""
    property var wallpaperList: []
    // Избранные обои: массив путей, хранится в state/wall-favorites.json
    property var wallFavorites: []
    function isFavorite(p) { return wallFavorites.indexOf(p) !== -1 }
    function toggleFavorite(p) {
        if (!p) return
        var arr = wallFavorites.slice()
        var i = arr.indexOf(p)
        if (i === -1) arr.push(p); else arr.splice(i, 1)
        wallFavorites = arr
        saveFavoritesProc.command = ["bash", "-c", "printf '%s' \"$1\" > \"$2\"", "_",
                                     JSON.stringify(arr), statePath + "/wall-favorites.json"]
        saveFavoritesProc.running = true
    }
    // Раздел обоев: 0 — все, 1 — Steam (Мастерская Wallpaper Engine), 2 — избранные
    property int wallCategory: 0
    property int steamWallCount: {
        var n = 0
        for (var i = 0; i < wallpaperList.length; i++) if (isSteamWall(wallpaperList[i].path)) n++
        return n
    }
    property var filteredWallpapers: {
        var favs = wallFavorites
        var cat = wallCategory
        var result = []
        for (var i = 0; i < wallpaperList.length; i++) {
            var w = wallpaperList[i]
            if (cat === 1 && !isSteamWall(w.path)) continue
            if (cat === 2 && favs.indexOf(w.path) === -1) continue
            if (wallSearchTerm !== "" && !w.name.toLowerCase().includes(wallSearchTerm)) continue
            result.push(w)
        }
        return result
    }
    property int wallSelectedIndex: 0
    property string currentWallpaper: ""
    property bool wallsLoaded: false
    property bool thumbsReady: false
    property bool walApplying: false
    property var wallpaperHashes: ({})

    // Видео-обои: "mpvpaper" или "quickshell" (свой слой с QtMultimedia)
    property string wallBackend: "mpvpaper"
    property bool mpvpaperAvailable: false
    property string effectiveWallBackend: (wallBackend === "mpvpaper" && !mpvpaperAvailable) ? "quickshell" : wallBackend
    property var videoWalls: ({})          // монитор -> видео, которое играет слой quickshell

    // Обои на нескольких мониторах: одни на все или разные на каждом
    property bool wallSplit: false         // false — одни обои на все мониторы
    property string wallTarget: ""         // монитор, на который ставим обои в режиме «разные»
    property var monitorWalls: ({})        // монитор -> путь к обоям
    // Мониторы слева направо
    property var wallScreens: {
        var s = []
        for (var i = 0; i < Quickshell.screens.length; i++) s.push(Quickshell.screens[i])
        s.sort(function(a, b) { return a.x - b.x || a.y - b.y })
        return s
    }
    // Что подсвечивать в сетке как «текущие обои»
    property string activeWallpaper: wallSplit && wallTarget !== "" && monitorWalls[wallTarget]
                                     ? monitorWalls[wallTarget] : currentWallpaper
    function setWallSplit(split) {
        if (split === wallSplit) return
        wallSplit = split
        saveState("wall-split", split ? "1" : "0")
        if (split) {
            if (wallTarget === "" && wallScreens.length > 0) wallTarget = wallScreens[0].name
        } else {
            // Возвращаемся к единым обоям — берём обои выбранного монитора
            var p = monitorWalls[wallTarget] || currentWallpaper
            if (p) applyWallpaper({ path: p, name: p.split("/").pop() })
        }
    }
    function thumbFor(p) {
        if (!p) return ""
        var h = wallpaperHashes ? wallpaperHashes[p] : ""
        if (h) return "file://" + cachePath + "/wallpaper-thumbs/" + h + ".jpg"
        return (isVideo(p) || isScene(p)) ? "" : "file://" + p
    }
    property string wallStillPath: ""      // статичный кадр текущих обоев (для блюра)
    property string wallScript: configPath + "/scripts/wallpaper.sh"
    function isVideo(p) { return /\.(mp4|webm|mkv|mov|m4v)$/i.test(p || "") }
    // Scene-обои Wallpaper Engine: папка в Мастерской Steam (appid 431960)
    function isSteamWall(p) { return (p || "").indexOf("/workshop/content/431960/") !== -1 }
    function isScene(p) { return isSteamWall(p) && !isVideo(p) }
    property string weScenesScript: configPath + "/scripts/we-scenes.sh"

    property bool wifiEnabled: true
    property string wifiCurrentSSID: ""
    property int wifiSignal: 0
    property var wifiNetworks: []
    property bool wifiScanning: false
    property string wifiPasswordSSID: ""
    property string wifiEnterpriseSSID: ""
    property string wifiEnterpriseSecurity: ""
    property string wifiLastSSID: ""
    property bool wifiMonitorReady: false
    property bool wifiConnecting: false
    property var wifiSaved: []             // сохранённые в NetworkManager сети: [{ uuid, ssid }]

    property bool btEnabled: true
    property var btPairedDevices: []
    property var btAvailableDevices: []
    property bool btScanning: false
    property string btConnectingMAC: ""

    property color walBackground: "#1e1e2e"
    property color walForeground: "#cdd6f4"
    property color walColor1: "#f38ba8"
    property color walColor2: "#a6e3a1"
    property color walColor4: "#f9e2af"
    property color walColor5: "#89b4fa"
    property color walColor8: "#6c7086"
    property color walColor13: "#f5c2e7"

    property int savedGifIndex: 0

    property int cpuTemp: 0
    property int gpuTemp: 0
    property int ramUsedMB: 0
    property int ramTotalMB: 0
    property int vramUsedMB: 0
    property int vramTotalMB: 0

    // Clock tools: timer / stopwatch / alarm
    property real clockNow: Date.now()
    property real timerDurationMs: 0
    property real timerEndAt: 0
    property real timerPausedMs: 0
    property string timerState: "idle"       // idle | running | paused
    property real stopwatchAccumMs: 0
    property real stopwatchStartAt: 0
    property string stopwatchState: "idle"   // idle | running | paused
    property bool alarmActive: false
    property int alarmHour: 7
    property int alarmMinute: 0
    property real alarmSetAt: 0
    property real alarmAt: 0
    readonly property real timerRemainingMs: timerState === "running" ? Math.max(0, timerEndAt - clockNow)
                                           : timerState === "paused" ? timerPausedMs : timerDurationMs
    readonly property real stopwatchElapsedMs: stopwatchAccumMs + (stopwatchState === "running" ? clockNow - stopwatchStartAt : 0)
    readonly property bool clockToolsActive: timerState !== "idle" || stopwatchState !== "idle" || alarmActive

    function pad2(n) { return n < 10 ? "0" + n : "" + n }

    function formatHMS(ms) {
        var s = Math.floor(ms / 1000)
        return pad2(Math.floor(s / 3600)) + ":" + pad2(Math.floor(s / 60) % 60) + ":" + pad2(s % 60)
    }

    function startTimer(ms) {
        if (ms <= 0) return
        clockNow = Date.now()
        timerDurationMs = ms
        timerEndAt = clockNow + ms
        timerState = "running"
    }

    function pauseTimer() {
        if (timerState !== "running") return
        timerPausedMs = Math.max(0, timerEndAt - Date.now())
        timerState = "paused"
    }

    function resumeTimer() {
        if (timerState !== "paused") return
        clockNow = Date.now()
        timerEndAt = clockNow + timerPausedMs
        timerState = "running"
    }

    function resetTimer() { timerState = "idle"; timerPausedMs = 0 }

    function startStopwatch() {
        if (stopwatchState === "running") return
        clockNow = Date.now()
        stopwatchStartAt = clockNow
        stopwatchState = "running"
    }

    function pauseStopwatch() {
        if (stopwatchState !== "running") return
        stopwatchAccumMs += Date.now() - stopwatchStartAt
        stopwatchState = "paused"
    }

    function resetStopwatch() { stopwatchState = "idle"; stopwatchAccumMs = 0 }

    function setAlarm(h, m) {
        var now = new Date()
        var target = new Date(now.getFullYear(), now.getMonth(), now.getDate(), h, m, 0, 0)
        if (target.getTime() <= now.getTime()) target.setDate(target.getDate() + 1)
        alarmHour = h
        alarmMinute = m
        clockNow = now.getTime()
        alarmSetAt = clockNow
        alarmAt = target.getTime()
        alarmActive = true
    }

    function cancelAlarm() { alarmActive = false }

    function clockNotify(title, body, icon) {
        Quickshell.execDetached(["notify-send", "-a", "Quickshell", "-u", "critical", "-i", icon, title, body])
        Quickshell.execDetached(["paplay", "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"])
    }

    Timer {
        interval: 100
        repeat: true
        running: root.clockToolsActive
        onTriggered: {
            root.clockNow = Date.now()
            if (root.timerState === "running" && root.clockNow >= root.timerEndAt) {
                root.timerState = "idle"
                root.clockNotify("Таймер", "Время вышло — " + root.formatHMS(root.timerDurationMs), "chronometer")
            }
            if (root.alarmActive && root.clockNow >= root.alarmAt) {
                root.alarmActive = false
                root.clockNotify("Будильник", "Время вышло — " + root.pad2(root.alarmHour) + ":" + root.pad2(root.alarmMinute), "alarm-clock")
            }
        }
    }




    function toggleLauncher(scr) { launcherVisible = panelToggle(launcherVisible, scr) }

    function toggleDashboard(scr) {
        dashboardVisible = panelToggle(dashboardVisible, scr)
        if (dashboardVisible) { wifiVisible = false; btVisible = false; powerVisible = false }
    }

    function toggleMusic(scr) {
        // Открыто на другом мониторе — переносим туда, а не закрываем
        if (scr && musicVisible && musicScreen !== scr) { musicScreen = scr; return }
        if (scr) musicScreen = scr
        musicVisible = !musicVisible
    }


    function togglePowerProfiles(scr) {
        powerVisible = panelToggle(powerVisible, scr)
        if (powerVisible) { wifiVisible = false; btVisible = false; dashboardVisible = false }
    }

    function setPowerProfile(profile) {
        powerProfileSetProc.command = ["powerprofilesctl", "set", profile]
        powerProfileSetProc.running = true
        root.powerVisible = false
    }


    function toggleWifi(scr) {
        wifiVisible = panelToggle(wifiVisible, scr)
        if (wifiVisible) { btVisible = false; dashboardVisible = false; powerVisible = false; refreshWifi() }
    }

    function toggleBluetooth(scr) {
        btVisible = panelToggle(btVisible, scr)
        if (btVisible) { wifiVisible = false; dashboardVisible = false; powerVisible = false; refreshBluetooth() }
    }

    function closeAllPanels() {
        dashboardVisible = false
        musicVisible = false
        launcherVisible = false
        wifiVisible = false
        btVisible = 
        powerVisible = false 
    }

    function isMacLikeName(name) {
        return /^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/.test(name)
    }

    function uniqueBtName(devices, mac, name) {
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].name === name)
                return name + " (" + mac.slice(-8).replace(/:/g, "") + ")"
        }
        return name
    }

    function refreshBluetooth() {
        root.btPairedDevices = []
        root.btAvailableDevices = []
        root.btScanning = false
        root.btConnectingMAC = ""
        if (!btStatusProc.running) btStatusProc.running = true
    }

    // Все действия идут через scripts/bt-connect.sh: он отличает «устройство выключено»
    // от «ключ устарел после Windows» и в последнем случае сам пересопрягает.
    property string btStatusMAC: ""
    property string btStatusCode: ""      // connecting | pairing | waiting | ok | fail
    property string btStatusText: ""
    function btRun(action, mac) {
        if (btActionProc.running) return
        root.btConnectingMAC = (action === "connect" || action === "pair") ? mac : ""
        root.btStatusMAC = mac
        root.btStatusCode = "connecting"
        root.btStatusText = ""
        btActionProc.command = [root.configPath + "/scripts/bt-connect.sh", action, mac]
        btActionProc.running = true
    }
    function connectBt(mac) { btRun("connect", mac) }
    function disconnectBt(mac) { btRun("disconnect", mac) }
    function pairBt(mac) { btRun("pair", mac) }
    function forgetBt(mac) { btRun("forget", mac) }

    function refreshWifi() {
        root.wifiNetworks = []
        root.wifiScanning = true
        if (!wifiStatusProc.running) wifiStatusProc.running = true
        if (!wifiCurrentProc.running) wifiCurrentProc.running = true
        if (!wifiScanProc.running) wifiScanProc.running = true
        refreshWifiSaved()
    }

    function refreshWifiSaved() {
        if (!wifiSavedProc.running) {
            wifiSavedProc.buf = []
            wifiSavedProc.running = true
        }
    }

    function wifiSavedUuid(ssid) {
        for (var i = 0; i < root.wifiSaved.length; i++)
            if (root.wifiSaved[i].ssid === ssid) return root.wifiSaved[i].uuid
        return ""
    }

    // Подключение к сети из списка: сохранённая — сразу, иначе спросить пароль/логин
    function connectWifi(ssid, security, forcePrompt) {
        var uuid = wifiSavedUuid(ssid)
        if (uuid !== "" && !forcePrompt) {
            root.wifiConnecting = true
            wifiConnectProc.ssid = ssid
            wifiConnectProc.uuid = uuid
            wifiConnectProc.security = security
            wifiConnectProc.password = ""
            wifiConnectProc.username = ""
            wifiConnectProc.enterprise = false
            wifiConnectProc.running = true
        } else if (isEnterpriseWifi(security)) {
            root.wifiEnterpriseSSID = ssid
            root.wifiEnterpriseSecurity = security
            root.wifiPasswordSSID = ""
        } else if (security !== "" && security !== "--") {
            root.wifiPasswordSSID = ssid
            root.wifiEnterpriseSSID = ""
            root.wifiEnterpriseSecurity = ""
        } else {
            root.wifiConnecting = true
            wifiConnectProc.ssid = ssid
            wifiConnectProc.uuid = ""
            wifiConnectProc.security = security
            wifiConnectProc.password = ""
            wifiConnectProc.username = ""
            wifiConnectProc.enterprise = false
            wifiConnectProc.running = true
        }
    }

    function forgetWifi(uuid) {
        wifiForgetProc.command = ["nmcli", "connection", "delete", "uuid", uuid]
        wifiForgetProc.running = true
    }

    function isEnterpriseWifi(security) {
        return security.indexOf("802.1X") !== -1
    }

    function notifyWifiChange(connected, ssid) {
        if (connected && ssid !== "")
            wifiNotifyProc.command = ["notify-send", "-a", "Quickshell", "-i", "network-wireless", "Wi-Fi подключено", ssid]
        else
            wifiNotifyProc.command = ["notify-send", "-a", "Quickshell", "-i", "network-wireless-offline", "Wi-Fi отключено", ssid !== "" ? ssid : "Сеть недоступна"]
        wifiNotifyProc.running = true
    }

    function notifyWifiError(ssid, message) {
        var text = message !== "" ? message : "Не удалось подключиться"
        wifiNotifyProc.command = ["notify-send", "-a", "Quickshell", "-i", "dialog-error", "Ошибка Wi-Fi", ssid + "\n" + text]
        wifiNotifyProc.running = true
    }

    function updateWifiConnection(ssid, signal) {
        var previous = root.wifiLastSSID
        root.wifiCurrentSSID = ssid
        root.wifiSignal = signal
        if (!root.wifiMonitorReady) {
            root.wifiLastSSID = ssid
            root.wifiMonitorReady = true
            return
        }
        if (ssid !== previous) {
            if (ssid !== "")
                notifyWifiChange(true, ssid)
            else if (previous !== "")
                notifyWifiChange(false, previous)
            root.wifiLastSSID = ssid
        }
    }

    function saveState(key, value) {
        saveStateProc.command = ["bash", "-c", "mkdir -p '" + statePath + "' && echo '" + value + "' > '" + statePath + "/" + key + "'"]
        saveStateProc.running = true
    }

    function loadState(key, callback) {
        loadStateProc.stateKey = key
        loadStateProc.callback = callback
        loadStateProc.command = ["cat", statePath + "/" + key]
        loadStateProc.running = true
    }

    Component.onCompleted: {
        initStateDir.running = true
    }

    Process {
        id: initStateDir
        command: ["mkdir", "-p", root.statePath]
        onExited: {
            walColorsProc.running = true
            appListProc.running = true
            loadUsageProc.running = true
            wallBackendProc.running = true
            loadFavoritesProc.running = true
            thumbDirProc.running = true
            loadGifIndexProc.running = true
        }
    }

    Process {
        id: loadGifIndexProc
        command: ["bash", "-c", "cat '" + root.statePath + "/gif-index' 2>/dev/null || echo '0'"]
        stdout: SplitParser {
            onRead: data => {
                var idx = parseInt(data.trim())
                root.savedGifIndex = isNaN(idx) ? 0 : idx
            }
        }
    }

    Process {
        id: saveStateProc
    }

    Process {
        id: loadStateProc
        property string stateKey: ""
        property var callback: null
        stdout: SplitParser {
            onRead: data => {
                if (loadStateProc.callback) {
                    loadStateProc.callback(data.trim())
                }
            }
        }
    }

    function launchApp(app) {
        launchProc.command = ["bash", "-c", app.exec + " &"]
        launchProc.running = true
        var usage = appUsage
        var updated = {}
        for (var key in usage) updated[key] = usage[key]
        updated[app.name] = (updated[app.name] || 0) + 1
        appUsage = updated
        saveUsageProc.command = ["bash", "-c", "echo '" + JSON.stringify(updated) + "' > '" + root.configPath + "/app_usage.json'"]
        saveUsageProc.running = true
        root.launcherVisible = false
    }

    // Пересчитать, какие мониторы играют видео силами quickshell
    function updateVideoWalls() {
        var v = {}
        var qs = root.effectiveWallBackend === "quickshell"
        for (var m in root.monitorWalls)
            if (qs && isVideo(root.monitorWalls[m])) v[m] = root.monitorWalls[m]
        root.videoWalls = v
    }

    function applyWallpaper(wallpaper) {
        var p = wallpaper.path
        var target = (root.wallSplit && root.wallTarget !== "") ? root.wallTarget : "all"
        var mw = {}
        for (var k in root.monitorWalls) mw[k] = root.monitorWalls[k]
        if (target === "all") {
            for (var i = 0; i < root.wallScreens.length; i++) mw[root.wallScreens[i].name] = p
        } else {
            mw[target] = p
        }
        root.monitorWalls = mw
        root.currentWallpaper = p
        root.walApplying = true
        updateVideoWalls()
        applyWallProc.command = ["bash", root.wallScript, "set", p, root.effectiveWallBackend, "--output", target]
        applyWallProc.running = true
    }

    function setWallBackend(b) {
        if (b === root.wallBackend) return
        root.wallBackend = b
        saveState("wall-backend", b)
        updateVideoWalls()
        // Перезапустить видео на новом бэкенде (на всех мониторах)
        var hasVideo = false
        for (var m in root.monitorWalls) if (isVideo(root.monitorWalls[m])) hasVideo = true
        if (hasVideo)
            Quickshell.execDetached(["bash", root.wallScript, "restore", root.effectiveWallBackend])
    }

    Process { id: saveFavoritesProc }
    Process {
        id: loadFavoritesProc
        command: ["bash", "-c", "cat '" + root.statePath + "/wall-favorites.json' 2>/dev/null || echo '[]'"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var a = JSON.parse(data.trim())
                    if (Array.isArray(a)) root.wallFavorites = a
                } catch (e) {}
            }
        }
    }

    Process {
        id: wallBackendProc
        command: ["bash", "-c", "b=$(cat '" + root.statePath + "/wall-backend' 2>/dev/null); echo \"${b:-mpvpaper} $(command -v mpvpaper >/dev/null && echo yes || echo no)\""]
        stdout: SplitParser {
            onRead: data => {
                var l = data.trim().split(" ")
                if (l[0] === "mpvpaper" || l[0] === "quickshell") root.wallBackend = l[0]
                root.mpvpaperAvailable = l[1] === "yes"
            }
        }
        onExited: currentWallProc.running = true
    }

    function loadWallpapers() {
        root.wallpaperList = []
        root.wallsLoaded = false
        root.thumbsReady = false
        if (!wallpaperListProc.running) wallpaperListProc.running = true
    }

    Process {
        id: thumbDirProc
        command: ["mkdir", "-p", root.cachePath + "/wallpaper-thumbs"]
        onExited: root.loadWallpapers()
    }

    Process {
        id: wallpaperListProc
        command: ["bash", "-c", "find '" + root.wallpaperPath + "' -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.m4v' \\) ! -name '.*' 2>/dev/null | sort; bash '" + root.weScenesScript + "' 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.length === 0) return
                var tab = line.indexOf("\t")
                var path = tab === -1 ? line : line.substring(0, tab)
                var parts = path.split("/")
                var name = tab === -1 ? parts[parts.length - 1] : "WE · " + line.substring(tab + 1)
                var current = root.wallpaperList.slice()
                current.push({ name: name, path: path })
                root.wallpaperList = current
            }
        }
        onExited: {
            root.wallsLoaded = true
            if (!thumbGenProc.running) thumbGenProc.running = true
        }
    }

    Process {
        id: thumbGenProc
        command: ["bash", "-c",
            "THUMB_DIR='" + root.cachePath + "/wallpaper-thumbs' && " +
            "WALL_DIR='" + root.wallpaperPath + "' && " +
            "cd \"$THUMB_DIR\" && " +
            "find \"$WALL_DIR\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.m4v' \\) ! -name '.*' 2>/dev/null | " +
            "while IFS= read -r f; do " +
            "  hash=$(echo -n \"$f\" | md5sum | cut -d' ' -f1); " +
            "  thumb=\"$THUMB_DIR/${hash}.jpg\"; " +
            "  if [ ! -f \"$thumb\" ] || [ \"$f\" -nt \"$thumb\" ]; then " +
            "    if command -v vipsthumbnail >/dev/null 2>&1; then " +
            "      case \"$f\" in " +
            "        *.mp4|*.webm|*.mkv|*.mov|*.m4v|*.MP4|*.WEBM|*.MKV|*.MOV) ffmpeg -nostdin -v error -y -ss 1 -i \"$f\" -frames:v 1 -vf 'scale=180:120:force_original_aspect_ratio=increase,crop=180:120' -q:v 3 \"$thumb\" 2>/dev/null || ffmpeg -nostdin -v error -y -i \"$f\" -frames:v 1 -vf 'scale=180:120:force_original_aspect_ratio=increase,crop=180:120' -q:v 3 \"$thumb\" 2>/dev/null ;; " +
            "        *.gif) convert \"${f}[0]\" -thumbnail 180x120^ -gravity center -extent 180x120 -quality 85 \"$thumb\" 2>/dev/null ;; " +
            "        *) vipsthumbnail \"$f\" -s 180x120 -o \"$thumb\" 2>/dev/null || convert \"$f\" -thumbnail 180x120^ -gravity center -extent 180x120 -quality 85 \"$thumb\" 2>/dev/null ;; " +
            "      esac; " +
            "    else " +
            "      case \"$f\" in " +
            "        *.mp4|*.webm|*.mkv|*.mov|*.m4v|*.MP4|*.WEBM|*.MKV|*.MOV) ffmpeg -nostdin -v error -y -ss 1 -i \"$f\" -frames:v 1 -vf 'scale=180:120:force_original_aspect_ratio=increase,crop=180:120' -q:v 3 \"$thumb\" 2>/dev/null || ffmpeg -nostdin -v error -y -i \"$f\" -frames:v 1 -vf 'scale=180:120:force_original_aspect_ratio=increase,crop=180:120' -q:v 3 \"$thumb\" 2>/dev/null ;; " +
            "        *.gif) convert \"${f}[0]\" -thumbnail 180x120^ -gravity center -extent 180x120 -quality 85 \"$thumb\" 2>/dev/null ;; " +
            "        *) convert \"$f\" -thumbnail 180x120^ -gravity center -extent 180x120 -quality 85 \"$thumb\" 2>/dev/null ;; " +
            "      esac; " +
            "    fi; " +
            "  fi; " +
            "done; " +
            "bash '" + root.weScenesScript + "' --thumbs 2>/dev/null | while IFS=$'\\t' read -r p d; do " +
            "  hash=$(echo -n \"$p\" | md5sum | cut -d' ' -f1); thumb=\"$THUMB_DIR/${hash}.jpg\"; " +
            "  prev=$(ls \"$d\"/preview.* 2>/dev/null | head -1); [ -n \"$prev\" ] || continue; " +
            "  if [ ! -f \"$thumb\" ] || [ \"$prev\" -nt \"$thumb\" ]; then " +
            "    convert \"${prev}[0]\" -thumbnail 180x120^ -gravity center -extent 180x120 -quality 85 \"$thumb\" 2>/dev/null; " +
            "  fi; " +
            "done"
        ]
        onExited: {
            root.thumbsReady = true
            if (!hashAllProc.running) hashAllProc.running = true
        }
    }

    Process {
    id: hashAllProc
    command: ["bash", "-c", "for f in '" + root.wallpaperPath + "'/*; do [ -f \"$f\" ] && echo \"$f|$(echo -n \"$f\" | md5sum | cut -d' ' -f1)\"; done; bash '" + root.weScenesScript + "' --dirs 2>/dev/null | while IFS= read -r d; do echo \"$d|$(echo -n \"$d\" | md5sum | cut -d' ' -f1)\"; done"]
    stdout: SplitParser {
        onRead: data => {
            var parts = data.trim().split("|")
            if (parts.length === 2 && parts[0] && parts[1]) {
                var updated = root.wallpaperHashes
                updated[parts[0]] = parts[1]
                root.wallpaperHashes = updated
                root.wallpaperHashesChanged()
            }
        }
    }
}

    Process {
        id: applyWallProc
        stdout: SplitParser {
            onRead: data => { if (data.trim().length > 0) root.wallStillPath = data.trim() }
        }
        onExited: {
            if (!walColorsProc.running) walColorsProc.running = true
        }
    }

    Process {
        id: walColorsProc
        command: ["bash", "-c", "cat '" + root.cachePath + "/wal/colors.json' 2>/dev/null"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var json = JSON.parse(data)
                    if (json.special) {
                        root.walBackground = json.special.background || root.walBackground
                        root.walForeground = json.special.foreground || root.walForeground
                    }
                    if (json.colors) {
                        root.walColor1 = json.colors.color1 || root.walColor1
                        root.walColor2 = json.colors.color2 || root.walColor2
                        root.walColor4 = json.colors.color4 || root.walColor4
                        root.walColor5 = json.colors.color5 || root.walColor5
                        root.walColor8 = json.colors.color8 || root.walColor8
                        root.walColor13 = json.colors.color13 || root.walColor13
                    }
                } catch(e) {}
            }
        }
        onExited: {
            if (root.walApplying) {
                if (!walStepSwaync.running) walStepSwaync.running = true
            }
        }
    }

    Process {
        id: walStepSwaync
        command: ["bash", "-c", "cp '" + root.cachePath + "/wal/colors-swaync.css' '" + root.configPath + "/../swaync/style.css' 2>/dev/null; pkill -SIGUSR1 swaync 2>/dev/null"]
        onExited: {
            if (!walStepBlur.running) walStepBlur.running = true
        }
    }

    Process {
        id: walStepBlur
        command: {
            var wp = (root.isVideo(root.currentWallpaper) || root.isScene(root.currentWallpaper)) && root.wallStillPath ? root.wallStillPath : root.currentWallpaper
            if (wp.endsWith(".gif"))
                return ["bash", "-c", "convert '" + wp + "[0]' -resize 1920x -blur 0x8 -quality 85 '" + root.wallpaperPath + "/.current-blurred.jpg' 2>/dev/null"]
            else
                return ["bash", "-c", "convert '" + wp + "' -resize 1920x -blur 0x8 -quality 85 '" + root.wallpaperPath + "/.current-blurred.jpg' 2>/dev/null"]
        }
        onExited: root.walApplying = false
    }

    Process {
        id: currentWallProc
        // Первая строка — общие обои и режим, дальше «монитор<TAB>путь»
        command: ["bash", "-c", "echo \"current\t$(readlink -f '" + root.wallpaperPath + "/current' 2>/dev/null)\t$(cat '" + root.statePath + "/wall-split' 2>/dev/null)\"; bash '" + root.wallScript + "' list"]
        property var acc: ({})
        onStarted: acc = {}
        stdout: SplitParser {
            onRead: data => {
                var f = data.split("\t")
                if (f.length < 2) return
                if (f[0] === "current") {
                    root.currentWallpaper = f[1]
                    root.wallSplit = (f[2] || "").trim() === "1"
                } else {
                    currentWallProc.acc[f[0]] = f[1].trim()
                }
            }
        }
        onExited: {
            root.monitorWalls = acc
            if (root.wallTarget === "" && root.wallScreens.length > 0) root.wallTarget = root.wallScreens[0].name
            // Видео на слое quickshell восстанавливаем сами (mpvpaper поднимает wallpaper.sh restore)
            root.updateVideoWalls()
        }
    }

    Process {
        id: loadUsageProc
        command: ["bash", "-c", "cat '" + root.configPath + "/app_usage.json' 2>/dev/null || echo '{}'"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try { root.appUsage = JSON.parse(data.trim()) } catch(e) { root.appUsage = {} }
            }
        }
    }

    Process { id: saveUsageProc }
    Process { id: launchProc }

    Process {
        id: appListProc
        command: ["bash", "-c",
            "for f in /usr/share/applications/*.desktop '" + root.homePath + "/.local/share/applications'/*.desktop; do " +
            "  [ -f \"$f\" ] || continue; " +
            "  grep -qi '^NoDisplay=true' \"$f\" && continue; " +
            "  grep -qi '^Hidden=true' \"$f\" && continue; " +
            "  name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); " +
            "  exec=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/ %[fFuUdDnNickvm]//g'); " +
            "  icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2-); " +
            "  [ -z \"$name\" ] && continue; " +
            "  [ -z \"$exec\" ] && continue; " +
            "  printf '%s\\t%s\\t%s\\n' \"$name\" \"$exec\" \"$icon\"; " +
            "done | sort -f -t$'\\t' -k1,1 | awk -F'\\t' '!seen[$1]++'"
        ]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.length === 0) return
                var parts = line.split("\t")
                if (parts.length < 2) return
                var current = root.appList.slice()
                current.push({ name: parts[0], exec: parts[1], icon: parts.length > 2 ? parts[2] : "" })
                root.appList = current
            }
        }
    }

    Process { id: wifiNotifyProc }

    Process {
        id: wifiStatusProc
        command: ["bash", "-c", "LANG=C LC_ALL=C nmcli radio wifi 2>/dev/null || echo 'disabled'"]
        stdout: SplitParser { onRead: data => root.wifiEnabled = data.trim() === "enabled" }
    }

    Process {
        id: wifiCurrentProc
        command: ["bash", "-c", "LANG=C LC_ALL=C nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | grep '^yes' | head -1"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":")
                if (parts.length >= 3)
                    root.updateWifiConnection(parts[1], parseInt(parts[2]) || 0)
                else
                    root.updateWifiConnection("", 0)
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!wifiCurrentProc.running) wifiCurrentProc.running = true }
    }

    Process {
        id: wifiScanProc
        command: ["bash", "-c", "LANG=C LC_ALL=C nmcli -t -f ssid,signal,security dev wifi list --rescan yes 2>/dev/null | head -20"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.length === 0) return
                var parts = line.split(":")
                if (parts.length < 2) return
                var ssid = parts[0]
                if (ssid === "" || ssid === root.wifiCurrentSSID) return
                var signal = parseInt(parts[1]) || 0
                var security = parts.length >= 3 ? parts[2] : ""
                var current = root.wifiNetworks.slice()
                for (var i = 0; i < current.length; i++) {
                    if (current[i].ssid === ssid) return
                }
                current.push({ ssid: ssid, signal: signal, security: security })
                root.wifiNetworks = current
            }
        }
        onExited: root.wifiScanning = false
    }

    Process {
        id: wifiToggleProc
        command: ["bash", "-c", root.wifiEnabled ? "LANG=C LC_ALL=C nmcli radio wifi off" : "LANG=C LC_ALL=C nmcli radio wifi on"]
        onExited: {
            if (!wifiStatusProc.running) wifiStatusProc.running = true
            if (!root.wifiEnabled) wifiScanDelayTimer.start()
        }
    }

    Timer {
        id: wifiScanDelayTimer
        interval: 2000
        repeat: false
        onTriggered: refreshWifi()
    }

    Process {
        id: wifiSavedProc
        property var buf: []
        command: ["bash", "-c", "export LANG=C LC_ALL=C; nmcli -t -f UUID,TYPE connection show 2>/dev/null | awk -F: '$2==\"802-11-wireless\" {print $1}' | while read -r u; do s=$(nmcli -g 802-11-wireless.ssid,802-11-wireless.mode connection show uuid \"$u\" 2>/dev/null | paste -sd'\\t'); printf '%s\\t%s\\n' \"$u\" \"$s\"; done"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.split("\t")
                // точки доступа (в т.ч. своя раздача) — не сети для подключения
                if (p.length >= 2 && p[1] !== "" && p[2] !== "ap")
                    wifiSavedProc.buf.push({ uuid: p[0], ssid: p[1].replace(/\\:/g, ":") })
            }
        }
        onExited: root.wifiSaved = wifiSavedProc.buf
    }

    Process {
        id: wifiForgetProc
        onExited: root.refreshWifiSaved()
    }

    Process {
        id: wifiConnectProc
        property string ssid: ""
        property string uuid: ""              // сохранённый профиль NetworkManager
        property string security: ""
        property string password: ""
        property string username: ""
        property bool enterprise: false
        property string lastOutput: ""
        command: {
            if (uuid !== "" && password === "")
                return ["bash", "-c", "LANG=C LC_ALL=C nmcli connection up uuid \"$1\" 2>&1", "_", uuid]
            if (uuid !== "" && !enterprise)
                return ["bash", "-c", "export LANG=C LC_ALL=C; nmcli connection modify uuid \"$1\" wifi-sec.psk \"$2\" 2>&1 && nmcli connection up uuid \"$1\" 2>&1", "_", uuid, password]
            var safeSsid = ssid.replace(/'/g, "'\\''")
            var safePass = password.replace(/'/g, "'\\''")
            var safeUser = username.replace(/'/g, "'\\''")
            if (enterprise)
                return ["bash", "-c",
                    "SSID='" + safeSsid + "'; USER='" + safeUser + "'; PASS='" + safePass + "'; " +
                    "CONN=''; " +
                    "if LANG=C LC_ALL=C nmcli -g 802-11-wireless.ssid connection show \"$SSID\" >/dev/null 2>&1; then CONN=\"$SSID\"; " +
                    "else for name in $(LANG=C LC_ALL=C nmcli -t -f NAME,TYPE connection show 2>/dev/null | grep ':802-11-wireless$' | cut -d: -f1); do " +
                    "  s=$(LANG=C LC_ALL=C nmcli -g 802-11-wireless.ssid connection show \"$name\" 2>/dev/null); " +
                    "  if [ \"$s\" = \"$SSID\" ]; then CONN=\"$name\"; break; fi; " +
                    "done; fi; " +
                    "if [ -z \"$CONN\" ]; then " +
                    "  CONN=\"$SSID\"; " +
                    "  LANG=C LC_ALL=C nmcli connection add type wifi con-name \"$CONN\" ssid \"$SSID\" wifi-sec.key-mgmt wpa-eap 802-1x.eap peap 802-1x.phase2-auth mschapv2 802-1x.identity \"$USER\" 802-1x.password \"$PASS\" 2>&1 || exit 1; " +
                    "else " +
                    "  LANG=C LC_ALL=C nmcli connection modify \"$CONN\" 802-1x.identity \"$USER\" 802-1x.password \"$PASS\" 2>&1 || exit 1; " +
                    "fi; " +
                    "LANG=C LC_ALL=C nmcli connection up \"$CONN\" 2>&1"]
            if (password !== "")
                return ["bash", "-c", "LANG=C LC_ALL=C nmcli dev wifi connect '" + safeSsid + "' password '" + safePass + "' 2>&1"]
            return ["bash", "-c", "LANG=C LC_ALL=C nmcli dev wifi connect '" + safeSsid + "' 2>&1"]
        }
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => wifiConnectProc.lastOutput = data.trim()
        }
        onExited: (exitCode) => {
            var targetSsid = wifiConnectProc.ssid
            var wasEnterprise = wifiConnectProc.enterprise
            var hadPassword = wifiConnectProc.password !== ""
            var savedOnly = wifiConnectProc.uuid !== "" && !hadPassword
            var security = wifiConnectProc.security
            wifiConnectProc.uuid = ""
            root.wifiConnecting = false
            root.wifiPasswordSSID = ""
            root.wifiEnterpriseSSID = ""
            root.wifiEnterpriseSecurity = ""
            if (exitCode !== 0) {
                var err = wifiConnectProc.lastOutput
                if (err.indexOf("Error:") !== -1)
                    err = err.split("Error:").pop().trim()
                else if (err.indexOf("Ошибка") !== -1)
                    err = err.split("Ошибка").pop().trim()
                root.notifyWifiError(targetSsid, err)
                if (savedOnly) {
                    // сохранённый пароль не подошёл — спросить новый
                    if (security !== "" && security !== "--") root.connectWifi(targetSsid, security, true)
                } else if (wasEnterprise)
                    root.wifiEnterpriseSSID = targetSsid
                else if (hadPassword)
                    root.wifiPasswordSSID = targetSsid
            }
            wifiConnectProc.lastOutput = ""
            root.refreshWifiSaved()
            if (!wifiCurrentProc.running) wifiCurrentProc.running = true
            if (!wifiScanProc.running) wifiScanProc.running = true
        }
    }

    Process {
        id: wifiDisconnectProc
        command: ["bash", "-c", "iface=$(LANG=C LC_ALL=C nmcli -t -f device,type dev status | grep ':wifi$' | cut -d: -f1 | head -1); [ -n \"$iface\" ] && LANG=C LC_ALL=C nmcli dev disconnect \"$iface\" 2>/dev/null"]
        onExited: {
            root.updateWifiConnection("", 0)
        }
    }

    Process {
        id: btStatusProc
        command: ["bash", "-c", "echo -e 'show\\nquit' | bluetoothctl 2>/dev/null | grep -q 'Powered: yes' && echo 'true' || echo 'false'"]
        stdout: SplitParser {
            onRead: data => root.btEnabled = data.trim() === "true"
        }
        onExited: {
            if (root.btEnabled && !btDevicesProc.running) btDevicesProc.running = true
        }
    }

    Process {
        id: btToggleOnProc
        command: ["bash", "-c", "echo -e 'power on\\nquit' | bluetoothctl 2>/dev/null"]
        onExited: btToggleDelayTimer.start()
    }

    Timer {
        id: btToggleDelayTimer
        interval: 1000
        repeat: false
        onTriggered: refreshBluetooth()
    }

    Process {
        id: btToggleOffProc
        command: ["bash", "-c", "echo -e 'power off\\nquit' | bluetoothctl 2>/dev/null"]
        onExited: {
            root.btEnabled = false
            root.btPairedDevices = []
            root.btAvailableDevices = []
        }
    }

    Process {
        id: btDevicesProc
        command: ["bash", "-c", "bluetoothctl devices Paired 2>/dev/null | grep '^Device' | while read -r line; do mac=$(echo \"$line\" | awk '{print $2}'); info=$(bluetoothctl info \"$mac\" 2>/dev/null); connected=$(echo \"$info\" | grep -oP 'Connected: \\K\\w+'); name=$(echo \"$info\" | grep -oP 'Name: \\K.*' | head -1); [ -z \"$name\" ] && name=$(echo \"$info\" | grep -oP 'Alias: \\K.*' | head -1); [ -z \"$name\" ] && name=$(echo \"$line\" | cut -d' ' -f3-); echo \"${mac}|${name}|${connected}\"; done"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.length === 0) return
                var parts = line.split("|")
                if (parts.length < 3) return
                var mac = parts[0]
                var name = parts[1]
                var connected = parts[2] === "yes"
                var current = root.btPairedDevices.slice()
                for (var i = 0; i < current.length; i++) {
                    if (current[i].mac === mac) return
                }
                current.push({ mac: mac, name: name, connected: connected })
                root.btPairedDevices = current
            }
        }
        onExited: {
            if (root.btVisible && root.btEnabled && !btScanProc.running) {
                root.btScanning = true
                root.btAvailableDevices = []
                btScanProc.running = true
            }
        }
    }

    Process {
        id: btScanProc
        command: ["bash", "-c", "bluetoothctl --timeout 15 scan on >/dev/null 2>&1; sleep 3; bluetoothctl devices 2>/dev/null | grep '^Device' | while read -r line; do mac=$(echo \"$line\" | awk '{print $2}'); info=$(bluetoothctl info \"$mac\" 2>/dev/null); paired=$(echo \"$info\" | grep -oP 'Paired: \\K\\w+'); [ \"$paired\" = \"yes\" ] && continue; name=$(echo \"$info\" | grep -oP 'Name: \\K.*' | head -1); [ -z \"$name\" ] && name=$(echo \"$info\" | grep -oP 'Alias: \\K.*' | head -1); [ -z \"$name\" ] && continue; echo \"$name\" | grep -qE '^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$' && continue; echo \"${mac}|${name}\"; done"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.length === 0) return
                var parts = line.split("|")
                if (parts.length < 2) return
                var mac = parts[0]
                var name = parts[1]
                if (mac.length !== 17 || root.isMacLikeName(name)) return
                var current = root.btAvailableDevices.slice()
                for (var j = 0; j < current.length; j++) {
                    if (current[j].mac === mac) return
                }
                name = root.uniqueBtName(current, mac, name)
                current.push({ mac: mac, name: name })
                root.btAvailableDevices = current
            }
        }
        onExited: root.btScanning = false
    }

    Process {
        id: btActionProc
        stdout: SplitParser {
            onRead: data => {
                var m = /^STATE (\S+) ?(.*)$/.exec(data.trim())
                if (!m) return
                root.btStatusCode = m[1]
                root.btStatusText = m[2]
            }
        }
        onExited: {
            root.btConnectingMAC = ""
            btStatusClearTimer.restart()
            btActionDelayTimer.start()
        }
    }

    Timer {
        id: btStatusClearTimer
        interval: root.btStatusCode === "fail" ? 8000 : 2500
        onTriggered: { root.btStatusMAC = ""; root.btStatusCode = ""; root.btStatusText = "" }
    }

    Timer {
        id: btActionDelayTimer
        interval: 1500
        repeat: false
        onTriggered: refreshBluetooth()
    }

    Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: { if (!sysStatsProc.running) sysStatsProc.running = true }
    }

    Process {
            id: sysStatsProc
            command: ["bash", "-c",
                "cpu=$(sensors 2>/dev/null | grep 'Core 0' | awk '{print $3}' | tr -d '+°C' | cut -d. -f1); " +
                "gpu=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' '); " +
                "vram=$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' '); " +
                "ram=$(free -m | awk '/^Mem:/{print $3\"|\"$2}'); " +
                "echo \"$cpu|$gpu|$ram|$vram\""
            ]
            stdout: SplitParser {
                onRead: data => {
                    var parts = data.trim().split("|")
                    if (parts.length >= 5) {
                        root.cpuTemp = parseInt(parts[0]) || 0
                        root.gpuTemp = parseInt(parts[1]) || 0
                        root.ramUsedMB = parseInt(parts[2]) || 0
                        root.ramTotalMB = parseInt(parts[3]) || 0
                        var vramParts = parts[4].split(",")
                        root.vramUsedMB = parseInt(vramParts[0]) || 0
                        root.vramTotalMB = parseInt(vramParts[1]) || 0
                    }
                }
            }
        }
        // ↑ здесь закрывается sysStatsProc — ниже уже новый, отдельный код

        Timer {
            interval: 5000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: { if (!powerProfileGetProc.running) powerProfileGetProc.running = true }
        }

        Process {
            id: powerProfileGetProc
            command: ["powerprofilesctl", "get"]
            stdout: SplitParser {
                onRead: data => {
                    var p = data.trim()
                    if (p.length > 0) root.activePowerProfile = p
                }
            }
        }

        Process {
            id: powerProfileSetProc
            onExited: { if (!powerProfileGetProc.running) powerProfileGetProc.running = true }
        }

    // ТУТ изменил 
    // Bar { screen: Quickshell.screens[0] }   
    // Bar { screen: Quickshell.screens[1] } 
    Instantiator {
        model: Quickshell.screens
        delegate: Bar { screen: modelData }
    }

    Dashboard {}
    MusicPanel {}
    HotspotService { id: hotspot }
    WifiPanel {}
    BluetoothPanel {}
    LauncherPanel {}
    VideoWallpaper {}
    PowerProfilesPanel {}

    IpcHandler {
        target: "launcher"
        function toggle() {
            root.activeTab = 3
            root.toggleLauncher()
        }
    }
    IpcHandler {
        target: "dashboard"
        function toggle() { root.toggleDashboard() }
    }
    IpcHandler {
        target: "music"
        function toggle() { root.toggleMusic() }
    }
    IpcHandler {
        target: "wallpaper"
        function toggle() {
            if (!root.launcherVisible) {
                root.activeTab = 1
                root.toggleLauncher()
            } else if (root.activeTab === 1) {
                root.toggleLauncher()
            } else {
                root.activeTab = 1
                if (!root.wallsLoaded) root.loadWallpapers()
            }
        }
    }
    IpcHandler {
        target: "randomwallpaper"
        function apply(path: string) {
            root.applyWallpaper({ path: path, name: path.split("/").pop() })
        }
    }
    IpcHandler {
        target: "wifi"
        function toggle() { root.toggleWifi() }
    }
    IpcHandler {
        target: "timer"
        function start(seconds: int) { root.startTimer(seconds * 1000) }
        function stop() { root.resetTimer() }
    }
    IpcHandler {
        target: "bluetooth"
        function toggle() { root.toggleBluetooth() }
    }
    IpcHandler {
        target: "control"
        function toggle() {
            if (root.launcherVisible && root.activeTab === 3) { root.launcherVisible = false; return }
            root.activeTab = 3
            root.panelScreen = root.screenFor(null)
            root.launcherVisible = true
        }
    }
}