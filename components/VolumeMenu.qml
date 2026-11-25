import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

// Выпадающий микшер под индикатором громкости: общая громкость, устройство
// вывода, MPRIS-плееры (пауза/переключение) и приложения, играющие звук (мьют/громкость).
PopupWindow {
    id: menu
    property Item anchorItem
    property bool anchorHovered: false
    readonly property bool hovered: popHover.hovered
    readonly property string ff: "JetBrainsMono Nerd Font"

    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? anchorItem.width / 2 : 0
    anchor.rect.y: anchorItem ? anchorItem.height + 4 : 0
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Bottom
    color: "transparent"
    implicitWidth: 300
    implicitHeight: body.implicitHeight + 20

    // плавное появление: окно живёт, пока идёт анимация закрытия
    property bool open: false
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
    visible: reveal > 0.001

    // открытие по наведению с небольшой задержкой, закрытие — когда курсор ушёл и с кнопки, и с окна
    Timer {
        id: openTimer
        interval: 220
        onTriggered: menu.open = true
    }
    Timer {
        id: closeTimer
        interval: 450
        onTriggered: if (!menu.anchorHovered && !menu.hovered) menu.open = false
    }
    onAnchorHoveredChanged: {
        if (anchorHovered) { closeTimer.stop(); if (!open) openTimer.restart() }
        else { openTimer.stop(); closeTimer.restart() }
    }
    onHoveredChanged: if (hovered) closeTimer.stop(); else closeTimer.restart()

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
    readonly property var sinks: nodes.filter(function(n) { return n && n.isSink && !n.isStream && n.audio })
    // воспроизводящие потоки: media.class = Stream/Output/Audio (захват вроде cava не показываем)
    readonly property var streams: nodes.filter(function(n) {
        if (!n || !n.isStream || !n.audio) return false
        var c = (n.properties || {})["media.class"] || ""
        return c ? c.indexOf("Stream/Output") === 0 : n.isSink
    })
    readonly property var players: Mpris.players ? Mpris.players.values : []

    PwObjectTracker { objects: (menu.sink ? [menu.sink] : []).concat(menu.streams) }

    function appName(n) {
        var p = n.properties || {}
        return p["application.name"] || n.description || n.nickname || n.name || "Приложение"
    }
    function appIcon(n) {
        var p = n.properties || {}
        var i = p["application.icon-name"] || p["application.process.binary"] || ""
        return i ? "image://icon/" + i.toLowerCase() : ""
    }

    component VolSlider: Item {
        id: vs
        property var node: null
        readonly property real v: node && node.audio ? Math.min(1, node.audio.volume) : 0
        readonly property bool muted: !!(node && node.audio && node.audio.muted)
        implicitHeight: 18
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 5; radius: 3
            color: Qt.rgba(1, 1, 1, 0.1)
            Rectangle {
                width: parent.width * vs.v; height: parent.height; radius: 3
                color: vs.muted ? root.walColor8 : root.walColor5
                Behavior on width { NumberAnimation { duration: 80 } }
            }
        }
        Rectangle {
            x: vs.width * vs.v - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 12; height: 12; radius: 6
            color: root.walForeground
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function setAt(x) { if (vs.node && vs.node.audio) vs.node.audio.volume = Math.max(0, Math.min(1, x / width)) }
            onPressed: function(m) { setAt(m.x) }
            onPositionChanged: function(m) { if (pressed) setAt(m.x) }
            onWheel: function(w) {
                if (vs.node && vs.node.audio)
                    vs.node.audio.volume = Math.max(0, Math.min(1, vs.node.audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05)))
            }
        }
    }

    component IconBtn: Rectangle {
        id: ib
        property string glyph: ""
        property color tint: root.walForeground
        property bool active: false
        signal clicked()
        width: 24; height: 24; radius: 7
        color: active ? Qt.rgba(tint.r, tint.g, tint.b, 0.2) : (ibMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
        Text {
            anchors.centerIn: parent
            text: ib.glyph
            color: ib.tint
            font.pixelSize: 13
            font.family: "JetBrainsMono Nerd Font"
        }
        MouseArea {
            id: ibMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.clicked()
        }
    }

    component SubTitle: Text {
        color: root.walColor8
        font.pixelSize: 10
        font.bold: true
        font.family: "JetBrainsMono Nerd Font"
        Layout.topMargin: 4
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        opacity: menu.reveal
        transform: [
            Scale { origin.x: menu.width / 2; origin.y: 0; xScale: 0.94 + 0.06 * menu.reveal; yScale: 0.9 + 0.1 * menu.reveal },
            Translate { y: (1 - menu.reveal) * -8 }
        ]
        color: Qt.rgba(root.walBackground.r, root.walBackground.g, root.walBackground.b, 0.92)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        HoverHandler { id: popHover }

        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 6

            // ─── общая громкость ───
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                IconBtn {
                    readonly property bool m: !!(menu.sink && menu.sink.audio && menu.sink.audio.muted)
                    glyph: m ? "\u{F075F}" : "\u{F057E}"
                    tint: m ? root.walColor1 : root.walColor5
                    onClicked: if (menu.sink && menu.sink.audio) menu.sink.audio.muted = !menu.sink.audio.muted
                }
                VolSlider { Layout.fillWidth: true; node: menu.sink }
                Text {
                    Layout.preferredWidth: 36
                    horizontalAlignment: Text.AlignRight
                    text: menu.sink && menu.sink.audio ? Math.round(menu.sink.audio.volume * 100) + "%" : "—"
                    color: root.walForeground
                    font.pixelSize: 11
                    font.bold: true
                    font.family: menu.ff
                }
            }

            // ─── устройство вывода ───
            SubTitle { text: "ВЫВОД"; visible: menu.sinks.length > 1 }
            Repeater {
                model: menu.sinks.length > 1 ? menu.sinks : []
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool cur: menu.sink === modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    radius: 7
                    color: cur ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.15) : (sinkMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8
                        Rectangle {
                            width: 9; height: 9; radius: 5
                            color: cur ? root.walColor5 : "transparent"
                            border.width: 1
                            border.color: cur ? root.walColor5 : root.walColor8
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.description || modelData.nickname || modelData.name
                            color: cur ? root.walColor5 : root.walForeground
                            font.pixelSize: 11
                            font.family: menu.ff
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        id: sinkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Pipewire.preferredDefaultAudioSink = modelData
                    }
                }
            }

            // ─── плееры ───
            SubTitle { text: "ПЛЕЕРЫ"; visible: menu.players.length > 0 }
            Repeater {
                model: menu.players
                delegate: Rectangle {
                    id: pl
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 10
                    color: Qt.rgba(0, 0, 0, 0.25)
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 7
                        spacing: 8
                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 8
                            color: Qt.rgba(1, 1, 1, 0.06)
                            clip: true
                            Image {
                                id: art
                                anchors.fill: parent
                                source: pl.modelData.trackArtUrl || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: art.status !== Image.Ready
                                text: "\u{F075A}"
                                color: root.walColor8
                                font.pixelSize: 16
                                font.family: menu.ff
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: pl.modelData.trackTitle || pl.modelData.identity || "Плеер"
                                color: pl.modelData.isPlaying ? root.walForeground : root.walColor8
                                font.pixelSize: 11
                                font.bold: true
                                font.family: menu.ff
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: (pl.modelData.trackArtist ? pl.modelData.trackArtist + " · " : "") + (pl.modelData.identity || "")
                                color: root.walColor8
                                font.pixelSize: 9
                                font.family: menu.ff
                                elide: Text.ElideRight
                            }
                        }
                        IconBtn {
                            visible: pl.modelData.canGoPrevious
                            glyph: "\u{F04AE}"
                            onClicked: pl.modelData.previous()
                        }
                        IconBtn {
                            glyph: pl.modelData.isPlaying ? "\u{F03E4}" : "\u{F040A}"
                            tint: root.walColor5
                            active: pl.modelData.isPlaying
                            onClicked: pl.modelData.togglePlaying()
                        }
                        IconBtn {
                            visible: pl.modelData.canGoNext
                            glyph: "\u{F04AD}"
                            onClicked: pl.modelData.next()
                        }
                    }
                }
            }

            // ─── приложения ───
            SubTitle { text: "ПРИЛОЖЕНИЯ"; visible: menu.streams.length > 0 }
            Repeater {
                model: menu.streams
                delegate: Rectangle {
                    id: st
                    required property var modelData
                    readonly property bool muted: !!(modelData.audio && modelData.audio.muted)
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    radius: 10
                    color: Qt.rgba(0, 0, 0, 0.25)
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 7
                        spacing: 8
                        Item {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            Image {
                                id: appImg
                                anchors.fill: parent
                                source: menu.appIcon(st.modelData)
                                sourceSize: Qt.size(22, 22)
                                visible: status === Image.Ready
                                opacity: st.muted ? 0.4 : 1
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: appImg.status !== Image.Ready
                                text: "\u{F075A}"
                                color: root.walColor8
                                font.pixelSize: 16
                                font.family: menu.ff
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: menu.appName(st.modelData) + ((st.modelData.properties || {})["media.name"] ? " · " + st.modelData.properties["media.name"] : "")
                                color: st.muted ? root.walColor8 : root.walForeground
                                font.pixelSize: 10
                                font.family: menu.ff
                                elide: Text.ElideRight
                            }
                            VolSlider { Layout.fillWidth: true; node: st.modelData }
                        }
                        IconBtn {
                            glyph: st.muted ? "\u{F075F}" : "\u{F057E}"
                            tint: st.muted ? root.walColor1 : root.walForeground
                            active: st.muted
                            onClicked: if (st.modelData.audio) st.modelData.audio.muted = !st.modelData.audio.muted
                        }
                    }
                }
            }

            Text {
                visible: menu.players.length === 0 && menu.streams.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 4
                horizontalAlignment: Text.AlignHCenter
                text: "Сейчас ничего не играет"
                color: root.walColor8
                font.pixelSize: 11
                font.family: menu.ff
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "ЛКМ mute · ПКМ микшер · колесо громкость"
                color: root.walColor8
                font.pixelSize: 8
                font.family: menu.ff
                opacity: 0.6
            }
        }
    }
}
