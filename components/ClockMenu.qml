import Quickshell
import QtQuick
import QtQuick.Layouts

PopupWindow {
    id: menu
    property Item anchorItem
    property string section: ""        // "" | timer | alarm | calendar
    property int timerTab: 0           // 0 = таймер, 1 = секундомер
    property int calYear: new Date().getFullYear()
    property int calMonth: new Date().getMonth()

    readonly property var monthNames: ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
                                       "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]
    readonly property var weekDays: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    anchor.item: anchorItem
    anchor.rect.x: 0
    anchor.rect.y: anchorItem ? anchorItem.height + 4 : 0
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    grabFocus: true
    color: "transparent"
    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    onVisibleChanged: {
        if (visible) {
            var now = new Date()
            calYear = now.getFullYear()
            calMonth = now.getMonth()
            section = ""
        }
    }

    function shiftMonth(delta) {
        var m = calMonth + delta
        calYear += Math.floor(m / 12)
        calMonth = ((m % 12) + 12) % 12
    }

    function calendarCells() {
        var first = new Date(calYear, calMonth, 1)
        var offset = (first.getDay() + 6) % 7
        var today = new Date()
        var cells = []
        for (var i = 0; i < 42; i++) {
            var d = new Date(calYear, calMonth, 1 - offset + i)
            cells.push({
                day: d.getDate(),
                inMonth: d.getMonth() === calMonth,
                isToday: d.toDateString() === today.toDateString(),
                weekend: d.getDay() === 0 || d.getDay() === 6
            })
        }
        return cells
    }

    component Glyph: Text {
        property int code: 0
        text: String.fromCodePoint(code)
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 18
        color: root.walForeground
    }

    component MenuButton: Rectangle {
        id: mb
        property int code: 0
        property string name: ""
        property bool active: menu.section === name
        property color accent: root.walColor5
        width: 40; height: 40; radius: 12
        color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.25)
                      : mbMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        Glyph {
            anchors.centerIn: parent
            code: mb.code
            color: mb.active ? mb.accent : root.walForeground
            font.pixelSize: 20
        }

        MouseArea {
            id: mbMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: menu.section = mb.name
            onClicked: menu.section = mb.name
        }
    }

    component ActionButton: Rectangle {
        id: ab
        property int code: 0
        property string label: ""
        property color accent: root.walColor5
        signal clicked()
        Layout.fillWidth: true
        height: 34; radius: 10
        opacity: enabled ? 1 : 0.4
        color: abMa.containsMouse ? Qt.rgba(accent.r, accent.g, accent.b, 0.30)
                                             : Qt.rgba(accent.r, accent.g, accent.b, 0.16)
        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
            anchors.centerIn: parent
            spacing: 6
            Glyph { code: ab.code; color: ab.accent; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: ab.label
                color: root.walForeground
                font.pixelSize: 12
                font.bold: true
                font.family: "JetBrainsMono Nerd Font"
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: abMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ab.clicked()
        }
    }

    // Поле ввода двух цифр: ввод с клавиатуры или колесом мыши
    component TimeField: Rectangle {
        id: tf
        property int value: 0
        property int maxValue: 59
        width: 58; height: 52; radius: 12
        color: Qt.rgba(0, 0, 0, 0.3)
        border.width: input.activeFocus ? 1 : 0
        border.color: root.walColor5

        property string typed: ""       // цифры, набранные с момента фокуса
        onValueChanged: input.text = root.pad2(value)

        TextInput {
            id: input
            anchors.fill: parent
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            text: root.pad2(tf.value)
            color: root.walForeground
            font.pixelSize: 26
            font.bold: true
            font.family: "JetBrainsMono Nerd Font"
            readOnly: true
            cursorVisible: false
            inputMethodHints: Qt.ImhDigitsOnly
            onActiveFocusChanged: tf.typed = ""

            // Ввод цифр вручную: "1" → 01, затем "6" → 16; третья цифра начинает заново
            Keys.onPressed: function(event) {
                if (event.text.length === 1 && event.text >= "0" && event.text <= "9") {
                    var t = (tf.typed.length >= 2 ? "" : tf.typed) + event.text
                    if (parseInt(t) > tf.maxValue) t = event.text
                    tf.typed = t
                    tf.value = parseInt(t)
                    event.accepted = true
                } else if (event.key === Qt.Key_Backspace) {
                    tf.typed = tf.typed.slice(0, -1)
                    tf.value = tf.typed === "" ? 0 : parseInt(tf.typed)
                    event.accepted = true
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                    var step = event.key === Qt.Key_Up ? 1 : -1
                    tf.typed = ""
                    tf.value = (tf.value + step + tf.maxValue + 1) % (tf.maxValue + 1)
                    event.accepted = true
                }
            }
        }

        WheelHandler {
            onWheel: function(event) {
                var step = event.angleDelta.y > 0 ? 1 : -1
                tf.typed = ""
                tf.value = (tf.value + step + tf.maxValue + 1) % (tf.maxValue + 1)
            }
        }
    }

    component Colon: Text {
        text: ":"
        color: root.walColor8
        font.pixelSize: 26
        font.bold: true
        font.family: "JetBrainsMono Nerd Font"
        anchors.verticalCenter: parent.verticalCenter
    }

    component Readout: Text {
        color: root.walForeground
        font.pixelSize: 32
        font.bold: true
        font.family: "JetBrainsMono Nerd Font"
        Layout.alignment: Qt.AlignHCenter
    }

    component ProgressLine: Rectangle {
        property real progress: 0
        property color accent: root.walColor5
        Layout.fillWidth: true
        height: 4; radius: 2
        color: Qt.rgba(0, 0, 0, 0.4)
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, parent.progress))
            height: parent.height
            radius: 2
            color: parent.accent
        }
    }

    component Card: Rectangle {
        default property alias content: cardColumn.data
        width: 272
        implicitHeight: cardColumn.implicitHeight + 28
        radius: 18
        color: Qt.rgba(root.walBackground.r, root.walBackground.g, root.walBackground.b, 0.88)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)

        ColumnLayout {
            id: cardColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: menu.visible = false

        Column {
            id: layout
            spacing: 6

            // Список иконок
            Rectangle {
                width: iconColumn.implicitWidth + 16
                height: 56
                radius: 18
                color: Qt.rgba(root.walBackground.r, root.walBackground.g, root.walBackground.b, 0.88)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)

                Row {
                    id: iconColumn
                    anchors.centerIn: parent
                    spacing: 6
                    MenuButton { name: "timer"; code: 0xF13AB; accent: root.walColor5 }
                    MenuButton { name: "alarm"; code: 0xF0020; accent: root.walColor4 }
                    MenuButton { name: "calendar"; code: 0xF0E17; accent: root.walColor2 }
                }
            }

            // Таймер / секундомер
            Card {
                visible: menu.section === "timer"

                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 10
                    color: Qt.rgba(0, 0, 0, 0.3)

                    Rectangle {
                        width: parent.width / 2 - 4
                        height: parent.height - 6
                        y: 3
                        x: menu.timerTab === 0 ? 3 : parent.width / 2 + 1
                        radius: 8
                        color: Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.3)
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }

                    Row {
                        anchors.fill: parent
                        Repeater {
                            model: ["Таймер", "Секундомер"]
                            Item {
                                width: parent.width / 2
                                height: parent.height
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: menu.timerTab === index ? root.walForeground : root.walColor8
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: menu.timerTab = index
                                }
                            }
                        }
                    }
                }

                // --- Таймер ---
                ColumnLayout {
                    visible: menu.timerTab === 0
                    Layout.fillWidth: true
                    spacing: 10

                    Row {
                        visible: root.timerState === "idle"
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        TimeField { id: tH; maxValue: 23; value: 0 }
                        Colon {}
                        TimeField { id: tM; maxValue: 59; value: 5 }
                        Colon {}
                        TimeField { id: tS; maxValue: 59; value: 0 }
                    }

                    Row {
                        visible: root.timerState === "idle"
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        Repeater {
                            model: [1, 5, 10, 25, 60]
                            Rectangle {
                                width: 42; height: 24; radius: 8
                                color: presetMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData < 60 ? modelData + "м" : "1ч"
                                    color: root.walForeground
                                    font.pixelSize: 11
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                                MouseArea {
                                    id: presetMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        tH.value = Math.floor(modelData / 60)
                                        tM.value = modelData % 60
                                        tS.value = 0
                                    }
                                }
                            }
                        }
                    }

                    Readout {
                        visible: root.timerState !== "idle"
                        text: root.formatHMS(root.timerRemainingMs + 999)
                        opacity: root.timerState === "paused" ? 0.6 : 1
                    }

                    ProgressLine {
                        visible: root.timerState !== "idle"
                        accent: root.walColor5
                        progress: root.timerDurationMs > 0 ? 1 - root.timerRemainingMs / root.timerDurationMs : 0
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        ActionButton {
                            visible: root.timerState === "idle"
                            code: 0xF040A; label: "Старт"; accent: root.walColor2
                            enabled: tH.value + tM.value + tS.value > 0
                            onClicked: root.startTimer(((tH.value * 60 + tM.value) * 60 + tS.value) * 1000)
                        }
                        ActionButton {
                            visible: root.timerState === "running"
                            code: 0xF03E4; label: "Пауза"; accent: root.walColor4
                            onClicked: root.pauseTimer()
                        }
                        ActionButton {
                            visible: root.timerState === "paused"
                            code: 0xF040A; label: "Дальше"; accent: root.walColor2
                            onClicked: root.resumeTimer()
                        }
                        ActionButton {
                            visible: root.timerState !== "idle"
                            code: 0xF04DB; label: "Стоп"; accent: root.walColor1
                            onClicked: root.resetTimer()
                        }
                    }
                }

                // --- Секундомер ---
                ColumnLayout {
                    visible: menu.timerTab === 1
                    Layout.fillWidth: true
                    spacing: 10

                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        Repeater {
                            model: 3
                            Row {
                                required property int index
                                spacing: 6
                                Colon { visible: index > 0 }
                                Rectangle {
                                    width: 58; height: 52; radius: 12
                                    color: Qt.rgba(0, 0, 0, 0.3)
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.formatHMS(root.stopwatchElapsedMs).split(":")[index]
                                        color: root.stopwatchState === "running" ? root.walForeground : root.walColor8
                                        font.pixelSize: 26
                                        font.bold: true
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        ActionButton {
                            visible: root.stopwatchState !== "running"
                            code: 0xF040A; label: root.stopwatchState === "paused" ? "Дальше" : "Старт"; accent: root.walColor2
                            onClicked: root.startStopwatch()
                        }
                        ActionButton {
                            visible: root.stopwatchState === "running"
                            code: 0xF03E4; label: "Пауза"; accent: root.walColor4
                            onClicked: root.pauseStopwatch()
                        }
                        ActionButton {
                            code: 0xF04DB; label: "Стоп"; accent: root.walColor1
                            enabled: root.stopwatchState !== "idle"
                            onClicked: root.resetStopwatch()
                        }
                    }
                }
            }

            // Будильник
            Card {
                visible: menu.section === "alarm"

                RowLayout {
                    Layout.fillWidth: true
                    Glyph { code: 0xF0020; color: root.walColor4 }
                    Text {
                        text: "Будильник"
                        color: root.walColor4
                        font.pixelSize: 14
                        font.bold: true
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Item { Layout.fillWidth: true }
                }

                Row {
                    visible: !root.alarmActive
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    TimeField {
                        id: aH; maxValue: 23
                        Component.onCompleted: value = root.alarmHour
                    }
                    Colon {}
                    TimeField {
                        id: aM; maxValue: 59
                        Component.onCompleted: value = root.alarmMinute
                    }
                }

                Readout {
                    visible: root.alarmActive
                    text: root.pad2(root.alarmHour) + ":" + root.pad2(root.alarmMinute)
                }

                Text {
                    visible: root.alarmActive
                    Layout.alignment: Qt.AlignHCenter
                    text: "осталось " + root.formatHMS(Math.max(0, root.alarmAt - root.clockNow) + 999)
                    color: root.walColor8
                    font.pixelSize: 12
                    font.family: "JetBrainsMono Nerd Font"
                }

                ProgressLine {
                    visible: root.alarmActive
                    accent: root.walColor4
                    progress: root.alarmAt > root.alarmSetAt ? (root.clockNow - root.alarmSetAt) / (root.alarmAt - root.alarmSetAt) : 0
                }

                RowLayout {
                    Layout.fillWidth: true
                    ActionButton {
                        visible: !root.alarmActive
                        code: 0xF0021; label: "Старт"; accent: root.walColor2
                        onClicked: root.setAlarm(aH.value, aM.value)
                    }
                    ActionButton {
                        visible: root.alarmActive
                        code: 0xF04DB; label: "Стоп"; accent: root.walColor1
                        onClicked: root.cancelAlarm()
                    }
                }
            }

            // Календарь
            Card {
                visible: menu.section === "calendar"

                RowLayout {
                    Layout.fillWidth: true

                    Rectangle {
                        width: 28; height: 28; radius: 8
                        color: prevMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        Glyph { anchors.centerIn: parent; code: 0xF0141; color: root.walColor5 }
                        MouseArea {
                            id: prevMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: menu.shiftMonth(-1)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: menu.monthNames[menu.calMonth] + " " + menu.calYear
                        color: root.walForeground
                        font.pixelSize: 14
                        font.bold: true
                        font.family: "JetBrainsMono Nerd Font"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var now = new Date()
                                menu.calYear = now.getFullYear()
                                menu.calMonth = now.getMonth()
                            }
                        }
                    }

                    Rectangle {
                        width: 28; height: 28; radius: 8
                        color: nextMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                        Glyph { anchors.centerIn: parent; code: 0xF0142; color: root.walColor5 }
                        MouseArea {
                            id: nextMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: menu.shiftMonth(1)
                        }
                    }
                }

                Grid {
                    Layout.alignment: Qt.AlignHCenter
                    columns: 7
                    spacing: 2

                    Repeater {
                        model: menu.weekDays
                        Text {
                            width: 32; height: 22
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData
                            color: index >= 5 ? root.walColor1 : root.walColor8
                            font.pixelSize: 11
                            font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                        }
                    }

                    Repeater {
                        model: menu.calendarCells()
                        Rectangle {
                            width: 32; height: 28; radius: 8
                            color: modelData.isToday ? root.walColor5
                                 : dayMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                color: modelData.isToday ? root.walBackground
                                     : modelData.weekend ? root.walColor1 : root.walForeground
                                opacity: modelData.inMonth ? 1.0 : 0.3
                                font.pixelSize: 12
                                font.bold: modelData.inMonth
                                font.family: "JetBrainsMono Nerd Font"
                            }

                            MouseArea {
                                id: dayMa
                                anchors.fill: parent
                                hoverEnabled: true
                            }
                        }
                    }
                }

                WheelHandler {
                    onWheel: function(event) { menu.shiftMonth(event.angleDelta.y > 0 ? -1 : 1) }
                }
            }
        }
    }
}
