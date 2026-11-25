import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: musicPanel
    screen: root.musicScreen ?? Quickshell.screens[0]
    visible: true
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true; right: true }
    margins { top: root.musicVisible ? 50 : -350; left: 0; right: 0 }
    implicitWidth: 400
    implicitHeight: musicPanel.gifSelectorOpen ? 460 : (musicPanel.hasLyrics ? 260 : 188)
    color: "transparent"
    focusable: true
    WlrLayershell.keyboardFocus: root.musicVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    Behavior on margins.top { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    property string configPath: root.configPath
    property string gifPath: configPath + "/assets/gifs"
    property string playerStatus: "Stopped"
    property string trackTitle: ""
    property string trackArtist: ""
    property string trackAlbum: ""
    property string activePlayer: ""
    property string artUrl: ""
    property bool showAlbumArt: false
    property string coverSource: ""
    property string coverTrackKey: ""
    property string coverFetchKey: ""
    property string coverFailedKey: ""
    property bool isMusicPlayer: {
        var p = activePlayer.toLowerCase()
        return p.indexOf("spotify") >= 0 || p.indexOf("yandex") >= 0
    }
    property real position: 0
    property real displayPosition: 0
    property real lastPosition: 0
    property real length: 0
    property bool hasTrack: playerStatus === "Playing" || playerStatus === "Paused"
    property string plainLyrics: ""
    property string syncedLyrics: ""
    property var lrcLines: []
    property bool lyricsAvailable: false
    property string lyricsTrackKey: ""
    property string lyricsFetchKey: ""
    property string lyricsFailedKey: ""
    property var lyricsDisplayLines: {
        var _pos = displayPosition
        var _plain = plainLyrics
        var _lrc = lrcLines
        return getLyricsLines()
    }
    property bool hasLyrics: hasTrack && lyricsAvailable && lyricsDisplayLines.length > 0
    property var gifFiles: []
    property int currentGifIndex: root.savedGifIndex
    property int previewGifIndex: 0
    property bool gifSelectorOpen: false
    property bool gifsLoaded: false
    property int gifReloadCounter: 0
    property bool isApplyingGif: false
    property string currentGifSource: "file://" + gifPath + "/current.gif"
    property int pendingGifIndex: -1

    function formatTime(seconds) {
        var mins = Math.floor(seconds / 60)
        var secs = Math.floor(seconds % 60)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }

    function nextGif() {
        if (gifFiles.length > 0) {
            previewGifIndex = (previewGifIndex + 1) % gifFiles.length
        }
    }

    function prevGif() {
        if (gifFiles.length > 0) {
            previewGifIndex = (previewGifIndex - 1 + gifFiles.length) % gifFiles.length
        }
    }

    function applyGif() {
        if (isApplyingGif) return
        if (gifFiles.length > 0 && previewGifIndex < gifFiles.length) {
            isApplyingGif = true
            pendingGifIndex = previewGifIndex
            setGifProc.selFile = gifFiles[previewGifIndex]
            setGifProc.running = true
        }
    }

    function loadGifs() {
        if (gifListProc.running) return
        musicPanel.gifFiles = []
        musicPanel.gifsLoaded = false
        musicPanel.previewGifIndex = 0
        gifListProc.running = true
    }

    function gifFileName(path) {
        var parts = path.split("/")
        var name = parts[parts.length - 1]
        return name.replace(".gif", "")
    }

    function reloadMainGif() {
        musicPanel.gifReloadCounter++
        musicPanel.currentGifSource = "file://" + gifPath + "/current.gif?v=" + musicPanel.gifReloadCounter + "&t=" + Date.now()
        musicPanel.isApplyingGif = false
        musicPanel.pendingGifIndex = -1
    }

    function saveGifIndex() {
        root.saveState("gif-index", currentGifIndex.toString())
        root.savedGifIndex = currentGifIndex
    }

    function playerName() {
        return activePlayer !== "" ? activePlayer : "%any"
    }

    function parseLrc(text) {
        var result = []
        if (!text) return result
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line) continue
            var tags = line.match(/\[\d+:\d+(?:\.\d+)?\]/g)
            if (!tags) continue
            var lastTag = tags[tags.length - 1]
            var txt = line.substring(line.lastIndexOf(lastTag) + lastTag.length).trim()
            if (!txt) continue
            for (var j = 0; j < tags.length; j++) {
                var m = tags[j].match(/\[(\d+):(\d+(?:\.\d+)?)\]/)
                if (!m) continue
                result.push({
                    time: parseInt(m[1]) * 60 + parseFloat(m[2]),
                    text: txt
                })
            }
        }
        result.sort(function(a, b) { return a.time - b.time })
        return result
    }

    function getLyricsLines() {
        var pos = displayPosition
        if (lrcLines.length > 0 && hasTrack) {
            var idx = 0
            for (var i = 0; i < lrcLines.length; i++) {
                if (lrcLines[i].time <= pos) idx = i
                else break
            }
            var synced = []
            if (idx > 0) synced.push(lrcLines[idx - 1].text)
            synced.push(lrcLines[idx].text)
            if (idx + 1 < lrcLines.length) synced.push(lrcLines[idx + 1].text)
            return synced
        }

        if (plainLyrics !== "") {
            var nonEmpty = []
            var plainLines = plainLyrics.split("\n")
            for (var j = 0; j < plainLines.length; j++) {
                var part = plainLines[j].trim()
                if (part) nonEmpty.push(part)
            }
            if (nonEmpty.length === 0) return []
            var startIdx = Math.floor((pos / Math.max(length, 1)) * Math.max(nonEmpty.length - 3, 0))
            return nonEmpty.slice(startIdx, startIdx + 3)
        }

        return []
    }

    function clearLyrics() {
        plainLyrics = ""
        syncedLyrics = ""
        lrcLines = []
        lyricsAvailable = false
        lyricsTrackKey = ""
        lyricsFetchKey = ""
        lyricsFailedKey = ""
    }

    function clearCover() {
        coverSource = ""
        coverTrackKey = ""
        coverFetchKey = ""
        coverFailedKey = ""
    }

    function fetchCoverIfNeeded() {
        if (!isMusicPlayer || trackTitle === "" || trackArtist === "") {
            clearCover()
            return
        }
        var key = trackTitle + "\x1f" + trackArtist + "\x1f" + trackAlbum
        if (key === coverTrackKey) return
        if (key === coverFailedKey) return
        if (key === coverFetchKey && coverProc.running) return
        if (coverProc.running)
            coverProc.running = false
        coverFetchKey = key
        coverSource = ""
        coverProc.trackTitle = trackTitle
        coverProc.trackArtist = trackArtist
        coverProc.trackAlbum = trackAlbum
        coverProc.artUrl = artUrl
        coverProc.running = true
    }

    function fetchLyricsIfNeeded() {
        if (!isMusicPlayer || trackTitle === "" || trackArtist === "") {
            clearLyrics()
            return
        }
        var key = trackTitle + "\x1f" + trackArtist + "\x1f" + trackAlbum
        if (key === lyricsTrackKey) return
        if (key === lyricsFailedKey) return
        if (key === lyricsFetchKey && lyricsProc.running) return
        lyricsFetchKey = key
        lyricsAvailable = false
        plainLyrics = ""
        syncedLyrics = ""
        lrcLines = []
        lyricsProc.trackTitle = trackTitle
        lyricsProc.trackArtist = trackArtist
        lyricsProc.trackAlbum = trackAlbum
        lyricsProc.trackDuration = Math.round(length).toString()
        lyricsProc.running = true
    }

    onGifSelectorOpenChanged: {
        if (!gifSelectorOpen) {
            previewGifIndex = currentGifIndex
        }
    }

    Timer {
        id: gifReloadTimer
        interval: 250
        repeat: false
        onTriggered: musicPanel.reloadMainGif()
    }

    Item {
        anchors.fill: parent
        focus: root.musicVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (musicPanel.gifSelectorOpen) {
                    musicPanel.gifSelectorOpen = false
                } else {
                    root.musicVisible = false
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Space && !musicPanel.gifSelectorOpen) {
                if (!playPauseProc.running) playPauseProc.running = true
                event.accepted = true
            } else if (event.key === Qt.Key_N && !musicPanel.gifSelectorOpen) {
                if (!nextProc.running) nextProc.running = true
                event.accepted = true
            } else if (event.key === Qt.Key_P && !musicPanel.gifSelectorOpen) {
                if (!prevProc.running) prevProc.running = true
                event.accepted = true
            } else if (event.key === Qt.Key_Left && musicPanel.gifSelectorOpen) {
                musicPanel.prevGif()
                event.accepted = true
            } else if (event.key === Qt.Key_Right && musicPanel.gifSelectorOpen) {
                musicPanel.nextGif()
                event.accepted = true
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && musicPanel.gifSelectorOpen) {
                if (musicPanel.previewGifIndex !== musicPanel.currentGifIndex) {
                    musicPanel.applyGif()
                }
                event.accepted = true
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Rectangle {
                width: 400
                height: musicPanel.hasLyrics ? 252 : 180
                color: Qt.rgba(root.walBackground.r, root.walBackground.g, root.walBackground.b, 0.7)
                radius: 15
                clip: true

                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: musicPanel.hasLyrics ? 132 : 150
                        spacing: 15

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6

                        Text {
                            text: musicPanel.trackTitle || "Nothing is playing"
                            color: root.walColor5
                            font.pixelSize: 15
                            font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: musicPanel.trackArtist || ""
                            color: root.walForeground
                            font.pixelSize: 12
                            font.family: "JetBrainsMono Nerd Font"
                            opacity: 0.7
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            visible: musicPanel.trackArtist !== ""
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: musicPanel.hasTrack

                            Text {
                                text: musicPanel.formatTime(musicPanel.position)
                                color: root.walColor8
                                font.pixelSize: 10
                                font.family: "JetBrainsMono Nerd Font"
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 4
                                radius: 2
                                color: Qt.rgba(0, 0, 0, 0.3)

                                Rectangle {
                                    width: musicPanel.length > 0 ? parent.width * (musicPanel.position / musicPanel.length) : 0
                                    height: parent.height
                                    radius: 2
                                    color: root.walColor5
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: function(mouse) {
                                        if (musicPanel.length > 0 && !seekProc.running) {
                                            var seekPos = (mouse.x / parent.width) * musicPanel.length
                                            seekProc.command = ["playerctl", "--player=" + musicPanel.playerName(), "position", seekPos.toString()]
                                            seekProc.running = true
                                        }
                                    }
                                }
                            }

                            Text {
                                text: musicPanel.formatTime(musicPanel.length)
                                color: root.walColor8
                                font.pixelSize: 10
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }

                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 12
                            opacity: musicPanel.hasTrack ? 1.0 : 0.5

                            Rectangle {
                                width: 32
                                height: 32
                                radius: 8
                                color: prevMa.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒮"
                                    color: root.walForeground
                                    font.pixelSize: 16
                                    font.family: "JetBrainsMono Nerd Font"
                                }

                                MouseArea {
                                    id: prevMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (!prevProc.running) prevProc.running = true
                                }
                            }

                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                color: root.walColor5

                                Text {
                                    anchors.centerIn: parent
                                    text: musicPanel.playerStatus === "Playing" ? "󰏤" : "󰐊"
                                    color: root.walBackground
                                    font.pixelSize: 18
                                    font.family: "JetBrainsMono Nerd Font"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (!playPauseProc.running) playPauseProc.running = true
                                }
                            }

                            Rectangle {
                                width: 32
                                height: 32
                                radius: 8
                                color: nextMa.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒭"
                                    color: root.walForeground
                                    font.pixelSize: 16
                                    font.family: "JetBrainsMono Nerd Font"
                                }

                                MouseArea {
                                    id: nextMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (!nextProc.running) nextProc.running = true
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 160
                        Layout.alignment: Qt.AlignBottom

                        Item {
                            id: gifContainer
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 160
                            height: 160

                            Loader {
                                id: danceGifLoader
                                anchors.fill: parent
                                active: !musicPanel.isApplyingGif && albumArtImage.status !== Image.Ready
                                sourceComponent: AnimatedImage {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: parent.height
                                    source: musicPanel.currentGifSource
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    playing: musicPanel.playerStatus === "Playing"
                                    paused: musicPanel.playerStatus !== "Playing"
                                    cache: false
                                    asynchronous: true
                                }
                            }

                            Image {
                                id: albumArtImage
                                anchors.fill: parent
                                visible: status === Image.Ready && musicPanel.coverSource !== ""
                                source: musicPanel.coverSource
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                cache: true
                                asynchronous: true
                                mipmap: true
                            }
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 5
                            anchors.rightMargin: 5
                            width: 24
                            height: 24
                            radius: 12
                            color: gifEditMa.containsMouse ? Qt.rgba(1,1,1,0.2) : Qt.rgba(0,0,0,0.3)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰏫"
                                color: root.walForeground
                                font.pixelSize: 12
                                font.family: "JetBrainsMono Nerd Font"
                            }

                            MouseArea {
                                id: gifEditMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!musicPanel.gifSelectorOpen) {
                                        musicPanel.loadGifs()
                                        musicPanel.gifSelectorOpen = true
                                    } else {
                                        musicPanel.gifSelectorOpen = false
                                    }
                                }
                            }
                        }
                    }
                    }

                    Column {
                        Layout.fillWidth: true
                        Layout.preferredHeight: musicPanel.hasLyrics ? 58 : 0
                        visible: musicPanel.hasLyrics
                        spacing: 4

                        Repeater {
                            model: musicPanel.lyricsDisplayLines

                            Text {
                                width: parent.width
                                text: modelData
                                color: (musicPanel.lrcLines.length > 0 && index === (musicPanel.lyricsDisplayLines.length > 2 ? 1 : 0))
                                    ? root.walColor5
                                    : root.walForeground
                                font.pixelSize: (musicPanel.lrcLines.length > 0 && index === (musicPanel.lyricsDisplayLines.length > 2 ? 1 : 0)) ? 15 : 13
                                font.bold: musicPanel.lrcLines.length > 0 && index === (musicPanel.lyricsDisplayLines.length > 2 ? 1 : 0)
                                font.family: "JetBrainsMono Nerd Font"
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                opacity: (musicPanel.lrcLines.length > 0 && index === (musicPanel.lyricsDisplayLines.length > 2 ? 1 : 0)) ? 1.0 : 0.55
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    visible: musicPanel.gifSelectorOpen
                    onClicked: musicPanel.gifSelectorOpen = false
                    z: -1
                }
            }

            Rectangle {
                id: dropdownCard
                width: 380
                height: 260
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 14
                color: Qt.rgba(root.walBackground.r, root.walBackground.g, root.walBackground.b, 0.85)
                border.color: Qt.rgba(1,1,1,0.1)
                border.width: 1
                visible: musicPanel.gifSelectorOpen
                clip: true

                layer.enabled: true
                layer.effect: DropShadow {
                    transparentBorder: true
                    horizontalOffset: 0
                    verticalOffset: 4
                    radius: 16
                    samples: 17
                    color: Qt.rgba(0,0,0,0.35)
                }

                ColumnLayout {
                    id: dropdownContent
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20

                        Text {
                            text: "Select Animation"
                            color: root.walColor5
                            font.pixelSize: 12
                            font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: musicPanel.gifFiles.length > 0
                            text: (musicPanel.previewGifIndex + 1) + " / " + musicPanel.gifFiles.length
                            color: root.walColor8
                            font.pixelSize: 10
                            font.family: "JetBrainsMono Nerd Font"
                            opacity: 0.6
                        }

                        Item { width: 6 }

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: dropCloseMa.containsMouse ? Qt.rgba(root.walColor1.r, root.walColor1.g, root.walColor1.b, 0.5) : Qt.rgba(1,1,1,0.08)
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                color: dropCloseMa.containsMouse ? root.walColor1 : root.walForeground
                                font.pixelSize: 10
                                font.family: "JetBrainsMono Nerd Font"
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: dropCloseMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: musicPanel.gifSelectorOpen = false
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.rgba(1,1,1,0.06)
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            id: previewContainer
                            anchors.fill: parent
                            radius: 12
                            color: Qt.rgba(0,0,0,0.2)
                            border.color: Qt.rgba(1,1,1,0.08)
                            border.width: 1
                            clip: true

                            Item {
                                id: previewPadding
                                anchors.fill: parent
                                anchors.margins: 12

                                Loader {
                                    id: previewGifLoader
                                    anchors.fill: parent
                                    active: musicPanel.gifSelectorOpen && musicPanel.gifsLoaded && musicPanel.gifFiles.length > 0
                                    sourceComponent: AnimatedImage {
                                        anchors.centerIn: parent
                                        width: parent.width
                                        height: parent.height
                                        source: (musicPanel.gifFiles.length > 0 && musicPanel.previewGifIndex < musicPanel.gifFiles.length) ? "file://" + musicPanel.gifFiles[musicPanel.previewGifIndex] : ""
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        playing: musicPanel.gifSelectorOpen
                                        cache: false
                                        asynchronous: true
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: musicPanel.gifFiles.length === 0 && musicPanel.gifsLoaded
                                text: "No gifs found"
                                color: root.walColor8
                                font.pixelSize: 11
                                font.family: "JetBrainsMono Nerd Font"
                                opacity: 0.5
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !musicPanel.gifsLoaded && musicPanel.gifSelectorOpen
                                text: "Loading..."
                                color: root.walColor8
                                font.pixelSize: 11
                                font.family: "JetBrainsMono Nerd Font"
                                opacity: 0.5
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 8
                                visible: musicPanel.gifFiles.length > 0 && musicPanel.gifsLoaded
                                width: nameLabel.implicitWidth + 16
                                height: 20
                                radius: 10
                                color: Qt.rgba(0,0,0,0.6)

                                Text {
                                    id: nameLabel
                                    anchors.centerIn: parent
                                    text: (musicPanel.gifFiles.length > 0 && musicPanel.previewGifIndex < musicPanel.gifFiles.length) ? musicPanel.gifFileName(musicPanel.gifFiles[musicPanel.previewGifIndex]) : ""
                                    color: root.walForeground
                                    font.pixelSize: 9
                                    font.family: "JetBrainsMono Nerd Font"
                                    opacity: 0.9
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 32
                            radius: 8
                            color: prevGifMa.containsMouse ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.25) : Qt.rgba(1,1,1,0.08)
                            border.color: prevGifMa.containsMouse ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.4) : Qt.rgba(1,1,1,0.05)
                            border.width: 1
                            opacity: musicPanel.gifFiles.length > 1 ? 1.0 : 0.3
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅁"
                                color: prevGifMa.containsMouse ? root.walColor5 : root.walForeground
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: prevGifMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: musicPanel.gifFiles.length > 1 && !musicPanel.isApplyingGif
                                onClicked: musicPanel.prevGif()
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 32
                            radius: 8
                            color: nextGifMa.containsMouse ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.25) : Qt.rgba(1,1,1,0.08)
                            border.color: nextGifMa.containsMouse ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.4) : Qt.rgba(1,1,1,0.05)
                            border.width: 1
                            opacity: musicPanel.gifFiles.length > 1 ? 1.0 : 0.3
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅂"
                                color: nextGifMa.containsMouse ? root.walColor5 : root.walForeground
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: nextGifMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: musicPanel.gifFiles.length > 1 && !musicPanel.isApplyingGif
                                onClicked: musicPanel.nextGif()
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredWidth: 85
                            Layout.preferredHeight: 32
                            radius: 8
                            color: {
                                if (musicPanel.isApplyingGif) return Qt.rgba(1,1,1,0.03)
                                if (musicPanel.previewGifIndex === musicPanel.currentGifIndex) return Qt.rgba(1,1,1,0.05)
                                return applyGifMa.pressed ? root.walColor5 : applyGifMa.containsMouse ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.35) : Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.18)
                            }
                            border.color: {
                                if (musicPanel.isApplyingGif) return Qt.rgba(1,1,1,0.05)
                                if (musicPanel.previewGifIndex === musicPanel.currentGifIndex) return Qt.rgba(1,1,1,0.08)
                                return applyGifMa.containsMouse ? root.walColor5 : Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.4)
                            }
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (musicPanel.isApplyingGif) return "Applying..."
                                    if (musicPanel.previewGifIndex === musicPanel.currentGifIndex) return "󰄬 Current"
                                    return "󰸞 Apply"
                                }
                                color: {
                                    if (musicPanel.isApplyingGif) return Qt.rgba(root.walForeground.r, root.walForeground.g, root.walForeground.b, 0.4)
                                    if (musicPanel.previewGifIndex === musicPanel.currentGifIndex) return Qt.rgba(root.walForeground.r, root.walForeground.g, root.walForeground.b, 0.3)
                                    return applyGifMa.pressed ? root.walBackground : root.walColor5
                                }
                                font.pixelSize: 11
                                font.bold: true
                                font.family: "JetBrainsMono Nerd Font"
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: applyGifMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: (musicPanel.previewGifIndex !== musicPanel.currentGifIndex && !musicPanel.isApplyingGif) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: musicPanel.previewGifIndex !== musicPanel.currentGifIndex && !musicPanel.isApplyingGif
                                onClicked: musicPanel.applyGif()
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 22
                        color: Qt.rgba(0,0,0,0.2)
                        radius: 6

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            Text {
                                text: "←→ nav"
                                color: root.walColor8
                                font.pixelSize: 9
                                font.family: "JetBrainsMono Nerd Font"
                                opacity: 0.6
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "↵ apply"
                                color: root.walColor8
                                font.pixelSize: 9
                                font.family: "JetBrainsMono Nerd Font"
                                opacity: 0.6
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "esc close"
                                color: root.walColor8
                                font.pixelSize: 9
                                font.family: "JetBrainsMono Nerd Font"
                                opacity: 0.6
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: root
        function onMusicVisibleChanged() {
            if (root.musicVisible) {
                focusTimer.start()
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: {
            musicPanel.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive
            releaseTimer.start()
        }
    }

    Timer {
        id: releaseTimer
        interval: 100
        repeat: false
        onTriggered: {
            musicPanel.WlrLayershell.keyboardFocus = WlrKeyboardFocus.OnDemand
        }
    }

    Process {
        id: gifListProc
        command: ["sh", "-c", "find '" + musicPanel.gifPath + "' -maxdepth 1 -name '*.gif' ! -name 'current.gif' -type f 2>/dev/null | sort"]
        stdout: SplitParser {
            onRead: data => {
                var file = data.trim()
                if (file.length > 0) {
                    var current = musicPanel.gifFiles.slice()
                    current.push(file)
                    musicPanel.gifFiles = current
                }
            }
        }
        onExited: {
            musicPanel.gifsLoaded = true
            if (musicPanel.gifFiles.length > 0) {
                musicPanel.previewGifIndex = Math.min(musicPanel.currentGifIndex, musicPanel.gifFiles.length - 1)
            }
        }
    }

    Process {
        id: setGifProc
        property string selFile: ""
        command: ["cp", selFile, musicPanel.gifPath + "/current.gif"]
        onExited: code => {
            if (code === 0 && musicPanel.pendingGifIndex >= 0) {
                musicPanel.currentGifIndex = musicPanel.pendingGifIndex
                musicPanel.gifSelectorOpen = false
                musicPanel.saveGifIndex()
                gifReloadTimer.start()
            } else {
                musicPanel.isApplyingGif = false
                musicPanel.pendingGifIndex = -1
            }
        }
    }

    Timer {
        id: playerPollTimer
        interval: 1000
        running: root.musicVisible && !musicPanel.gifSelectorOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!musicPollProc.running) musicPollProc.running = true
        }
    }

    Timer {
        id: positionPollTimer
        interval: 200
        running: root.musicVisible && musicPanel.playerStatus === "Playing" && !musicPanel.gifSelectorOpen
        repeat: true
        onTriggered: {
            if (!positionProc.running) positionProc.running = true
        }
    }

    Timer {
        id: lyricsSmoothTimer
        interval: 50
        running: root.musicVisible && musicPanel.playerStatus === "Playing" && musicPanel.lrcLines.length > 0
        repeat: true
        onTriggered: {
            musicPanel.displayPosition += 0.05
        }
    }

    Process {
        id: positionProc
        command: ["playerctl", "--player=" + musicPanel.playerName(), "position"]
        stdout: SplitParser {
            onRead: data => {
                var pos = parseFloat(data.trim()) || 0
                musicPanel.position = pos
                musicPanel.displayPosition = pos
                musicPanel.lastPosition = pos
            }
        }
    }

    Process {
        id: musicPollProc
        command: [musicPanel.configPath + "/scripts/media-poll.sh"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                var parts = data.trim().split("\x1f")
                if (parts.length < 8) return

                var newStatus = parts[0] || "Stopped"
                var wasPlaying = musicPanel.playerStatus === "Playing"
                var isNowPlaying = newStatus === "Playing"
                var prevKey = musicPanel.trackTitle + "\x1f" + musicPanel.trackArtist + "\x1f" + musicPanel.trackAlbum + "\x1f" + musicPanel.activePlayer

                musicPanel.playerStatus = newStatus
                musicPanel.trackTitle = parts[1] || ""
                musicPanel.trackArtist = parts[2] || ""
                musicPanel.trackAlbum = (parts.length > 8 && parts[8] !== "-") ? parts[8] : ""
                musicPanel.artUrl = parts[3] || ""
                musicPanel.activePlayer = parts[6] || ""
                musicPanel.showAlbumArt = parts[7] === "1"

                var pos = parseFloat(parts[4]) || 0
                musicPanel.length = parseFloat(parts[5]) || 0

                if (isNowPlaying) {
                    musicPanel.position = pos
                    musicPanel.displayPosition = pos
                    musicPanel.lastPosition = pos
                } else if (wasPlaying && !isNowPlaying) {
                    musicPanel.lastPosition = musicPanel.position
                    musicPanel.displayPosition = musicPanel.position
                } else if (!isNowPlaying) {
                    musicPanel.position = musicPanel.lastPosition
                    musicPanel.displayPosition = musicPanel.lastPosition
                }

                if (newStatus === "Stopped" || musicPanel.activePlayer === "") {
                    musicPanel.clearLyrics()
                    musicPanel.clearCover()
                    musicPanel.artUrl = ""
                    musicPanel.showAlbumArt = false
                    return
                }

                if (!musicPanel.isMusicPlayer) {
                    musicPanel.clearLyrics()
                    musicPanel.clearCover()
                }

                var newKey = musicPanel.trackTitle + "\x1f" + musicPanel.trackArtist + "\x1f" + musicPanel.trackAlbum + "\x1f" + musicPanel.activePlayer
                if (newKey !== prevKey) {
                    musicPanel.lyricsFailedKey = ""
                    musicPanel.fetchLyricsIfNeeded()
                    musicPanel.fetchCoverIfNeeded()
                }
            }
        }
        onExited: code => {
            if (code !== 0) {
                musicPanel.playerStatus = "Stopped"
                musicPanel.trackTitle = ""
                musicPanel.trackArtist = ""
                musicPanel.activePlayer = ""
                musicPanel.artUrl = ""
                musicPanel.showAlbumArt = false
                musicPanel.clearLyrics()
                musicPanel.clearCover()
            }
        }
    }

    Process {
        id: coverProc
        property string trackTitle: ""
        property string trackArtist: ""
        property string trackAlbum: ""
        property string artUrl: ""
        command: [
            musicPanel.configPath + "/scripts/fetch-cover.sh",
            trackTitle,
            trackArtist,
            trackAlbum,
            artUrl
        ]
        stdout: SplitParser {
            onRead: data => {
                var url = data.trim()
                if (url.indexOf("file://") === 0) {
                    musicPanel.coverSource = url
                }
            }
        }
        onExited: code => {
            if (code === 0) {
                musicPanel.coverTrackKey = musicPanel.coverFetchKey
                musicPanel.coverFailedKey = ""
            } else if (musicPanel.coverSource === "") {
                musicPanel.coverFailedKey = musicPanel.coverFetchKey
                musicPanel.coverFetchKey = ""
            }
        }
    }

    Process {
        id: lyricsProc
        property string trackTitle: ""
        property string trackArtist: ""
        property string trackAlbum: ""
        property string trackDuration: "0"
        command: [
            musicPanel.configPath + "/scripts/fetch-lyrics.sh",
            trackTitle,
            trackArtist,
            trackAlbum,
            trackDuration
        ]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                var plainIdx = data.indexOf("PLAIN\x1e")
                var syncedIdx = data.indexOf("SYNCED\x1e")
                if (plainIdx >= 0) {
                    var plainEnd = syncedIdx >= 0 ? syncedIdx : data.length
                    musicPanel.plainLyrics = data.substring(plainIdx + 6, plainEnd).replace(/\r\n/g, "\n").trim()
                }
                if (syncedIdx >= 0) {
                    musicPanel.syncedLyrics = data.substring(syncedIdx + 7).replace(/\r\n/g, "\n").trim()
                }
            }
        }
        onExited: code => {
            if (code === 0) {
                musicPanel.lrcLines = musicPanel.parseLrc(musicPanel.syncedLyrics)
                musicPanel.lyricsAvailable = musicPanel.plainLyrics !== "" || musicPanel.lrcLines.length > 0
                musicPanel.lyricsTrackKey = musicPanel.lyricsFetchKey
                musicPanel.lyricsFailedKey = ""
            } else {
                musicPanel.lyricsAvailable = false
                musicPanel.lyricsFailedKey = musicPanel.lyricsFetchKey
                musicPanel.lyricsFetchKey = ""
            }
        }
    }

    Process {
        id: playPauseProc
        command: ["playerctl", "--player=" + musicPanel.playerName(), "play-pause"]
        onExited: { if (!musicPollProc.running) musicPollProc.running = true }
    }

    Process {
        id: nextProc
        command: ["playerctl", "--player=" + musicPanel.playerName(), "next"]
        onExited: { if (!musicPollProc.running) musicPollProc.running = true }
    }

    Process {
        id: prevProc
        command: ["playerctl", "--player=" + musicPanel.playerName(), "previous"]
        onExited: { if (!musicPollProc.running) musicPollProc.running = true }
    }

    Process {
        id: seekProc
        command: ["playerctl", "--player=%any", "position", "0"]
    }
}