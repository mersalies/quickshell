import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: launcherPanel
    screen: root.panelScreen ?? Quickshell.screens[0]
    visible: true
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true }
    margins { top: 40; bottom: 10; left: root.launcherVisible ? 6 : -560 }
    // окно всегда 500px, видимый фон плавно меняет ширину; ввод принимается только над фоном
    implicitWidth: 500
    mask: Region { item: panelBg }
    color: "transparent"
    focusable: true
    WlrLayershell.keyboardFocus: root.launcherVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    Behavior on margins.left { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    Rectangle {
        id: panelBg
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: root.activeTab === 3 ? 500 : 420
        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        color: Qt.rgba(root.walBackground.r, root.walBackground.g, root.walBackground.b, 0.7)
        radius: 20

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                color: Qt.rgba(0, 0, 0, 0.3)
                radius: 12
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: root.activeTab === 3 ? Qt.rgba(root.walColor2.r, root.walColor2.g, root.walColor2.b, 0.2) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "\u{F062E}"
                                color: root.activeTab === 3 ? root.walColor2 : root.walColor8
                                font.pixelSize: 14
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            Text {
                                text: "Пульт"
                                color: root.activeTab === 3 ? root.walColor2 : root.walColor8
                                font.pixelSize: 13
                                font.bold: root.activeTab === 3
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeTab = 3
                                controlCenter.forceActiveFocus()
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: root.activeTab === 1 ? Qt.rgba(root.walColor13.r, root.walColor13.g, root.walColor13.b, 0.2) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "󰸉"
                                color: root.activeTab === 1 ? root.walColor13 : root.walColor8
                                font.pixelSize: 14
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            Text {
                                text: "Walls"
                                color: root.activeTab === 1 ? root.walColor13 : root.walColor8
                                font.pixelSize: 13
                                font.bold: root.activeTab === 1
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeTab = 1
                                root.wallSelectedIndex = 0
                                if (!root.wallsLoaded) root.loadWallpapers()
                                wallSearchInput.forceActiveFocus()
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: root.activeTab === 2 ? Qt.rgba(root.walColor4.r, root.walColor4.g, root.walColor4.b, 0.2) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "★"
                                color: root.activeTab === 2 ? root.walColor4 : root.walColor8
                                font.pixelSize: 14
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            Text {
                                text: "Fav" + (root.wallFavorites.length > 0 ? " " + root.wallFavorites.length : "")
                                color: root.activeTab === 2 ? root.walColor4 : root.walColor8
                                font.pixelSize: 13
                                font.bold: root.activeTab === 2
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeTab = 2
                                root.wallSelectedIndex = 0
                                if (!root.wallsLoaded) root.loadWallpapers()
                                wallSearchInput.forceActiveFocus()
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: root.activeTab === 0 ? Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.2) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: "󰀻"
                                color: root.activeTab === 0 ? root.walColor5 : root.walColor8
                                font.pixelSize: 14
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            Text {
                                text: "Apps"
                                color: root.activeTab === 0 ? root.walColor5 : root.walColor8
                                font.pixelSize: 13
                                font.bold: root.activeTab === 0
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeTab = 0
                                searchInput.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ControlCenter {
                    id: controlCenter
                    anchors.fill: parent
                    opacity: root.activeTab === 3 ? 1 : 0
                    visible: opacity > 0.01
                    enabled: root.activeTab === 3
                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    transform: Translate { y: (root.activeTab === 3) ? 0 : 14; Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } } }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    opacity: root.activeTab === 0 ? 1 : 0
                    visible: opacity > 0.01
                    enabled: root.activeTab === 0
                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    transform: Translate { y: (root.activeTab === 0) ? 0 : 14; Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } } }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: 12
                        border.width: searchInput.activeFocus ? 1 : 0
                        border.color: root.walColor5
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10
                            Text {
                                text: ""
                                color: root.walColor8
                                font.pixelSize: 14
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: root.walForeground
                                font.pixelSize: 14
                                font.family: "JetBrainsMono Nerd Font"
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                clip: true
                                Text {
                                    text: "Search apps..."
                                    color: root.walColor8
                                    visible: !parent.text
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    font: parent.font
                                    opacity: 0.6
                                }
                                onTextChanged: {
                                    root.searchTerm = text.toLowerCase()
                                    root.selectedIndex = 0
                                    appListView.contentY = 0
                                }
                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Down) {
                                        root.selectedIndex = Math.min(root.selectedIndex + 1, root.filteredApps.length - 1)
                                        appListView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Up) {
                                        root.selectedIndex = Math.max(root.selectedIndex - 1, 0)
                                        appListView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        if (root.filteredApps.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.filteredApps.length)
                                            root.launchApp(root.filteredApps[root.selectedIndex])
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Escape) {
                                        root.launcherVisible = false
                                        searchInput.text = ""
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Tab) {
                                        root.activeTab = 1
                                        if (!root.wallsLoaded) root.loadWallpapers()
                                        wallSearchInput.forceActiveFocus()
                                        event.accepted = true
                                    }
                                }
                            }
                            Text {
                                visible: searchInput.text.length > 0
                                text: "󰅖"
                                color: root.walColor8
                                font.pixelSize: 12
                                font.family: "JetBrainsMono Nerd Font"
                                opacity: clearAppMouse.containsMouse ? 1.0 : 0.7
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                                MouseArea {
                                    id: clearAppMouse
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchInput.text = ""
                                        searchInput.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: 15
                        clip: true

                        ListView {
                            id: appListView
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4
                            boundsBehavior: Flickable.StopAtBounds
                            currentIndex: root.selectedIndex
                            highlightFollowsCurrentItem: true
                            highlightMoveDuration: 100
                            model: root.filteredApps

                            property real targetContentY: 0
                            property bool animatingScroll: false

                            NumberAnimation {
                                id: appScrollAnim
                                target: appListView
                                property: "contentY"
                                duration: 300
                                easing.type: Easing.OutCubic
                                onFinished: appListView.animatingScroll = false
                            }

                            function smoothScrollTo(newY) {
                                var maxY = Math.max(0, contentHeight - height)
                                newY = Math.max(0, Math.min(newY, maxY))
                                if (animatingScroll) {
                                    appScrollAnim.stop()
                                }
                                animatingScroll = true
                                appScrollAnim.from = contentY
                                appScrollAnim.to = newY
                                targetContentY = newY
                                appScrollAnim.start()
                            }

                            function smoothScrollBy(delta) {
                                var base = animatingScroll ? targetContentY : contentY
                                smoothScrollTo(base + delta)
                            }

                            MouseArea {
                                anchors.fill: parent
                                propagateComposedEvents: true
                                onWheel: function(wheel) {
                                    var step = -wheel.angleDelta.y / 120.0 * 60
                                    appListView.smoothScrollBy(step)
                                }
                                onClicked: function(mouse) { mouse.accepted = false }
                                onPressed: function(mouse) { mouse.accepted = false }
                                onReleased: function(mouse) { mouse.accepted = false }
                            }

                            delegate: Rectangle {
                                width: appListView.width
                                height: 48
                                radius: 12
                                color: {
                                    if (index === root.selectedIndex)
                                        return Qt.rgba(root.walColor5.r, root.walColor5.g, root.walColor5.b, 0.2)
                                    if (appItemMouse.containsMouse)
                                        return Qt.rgba(1, 1, 1, 0.05)
                                    return "transparent"
                                }
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Rectangle {
                                    visible: index === root.selectedIndex
                                    width: 3
                                    height: 22
                                    radius: 2
                                    color: root.walColor5
                                    anchors.left: parent.left
                                    anchors.leftMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    anchors.topMargin: 6
                                    anchors.bottomMargin: 6
                                    spacing: 12
                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 8
                                        color: Qt.rgba(0, 0, 0, 0.2)
                                        Image {
                                            anchors.centerIn: parent
                                            width: 22
                                            height: 22
                                            source: {
                                                var icon = modelData.icon
                                                if (!icon || icon === "") return "image://icon/application-x-executable"
                                                if (icon.indexOf("/") === 0) return "file://" + icon
                                                return "image://icon/" + icon
                                            }
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            cache: true
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            color: index === root.selectedIndex ? root.walColor5 : root.walForeground
                                            font.pixelSize: 13
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.bold: index === root.selectedIndex
                                            elide: Text.ElideRight
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.exec
                                            color: root.walColor8
                                            font.pixelSize: 9
                                            font.family: "JetBrainsMono Nerd Font"
                                            elide: Text.ElideRight
                                            opacity: 0.7
                                        }
                                    }
                                    Text {
                                        visible: index === root.selectedIndex
                                        text: "↵"
                                        color: root.walColor5
                                        font.pixelSize: 14
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.bold: true
                                    }
                                }
                                MouseArea {
                                    id: appItemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.launchApp(modelData)
                                    onContainsMouseChanged: {
                                        if (containsMouse) root.selectedIndex = index
                                    }
                                }
                            }
                            ScrollBar.vertical: ScrollBar {
                                active: true
                                width: 4
                                policy: ScrollBar.AsNeeded
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: root.filteredApps.length === 0
                            text: "No apps found"
                            color: root.walColor8
                            font.pixelSize: 14
                            font.family: "JetBrainsMono Nerd Font"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: 10
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            Text { text: "↑↓ nav"; color: root.walColor8; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; opacity: 0.7 }
                            Item { Layout.fillWidth: true }
                            Text { text: "↵ launch"; color: root.walColor8; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; opacity: 0.7 }
                            Item { Layout.fillWidth: true }
                            Text { text: "tab walls"; color: root.walColor8; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; opacity: 0.7 }
                            Item { Layout.fillWidth: true }
                            Text { text: "esc close"; color: root.walColor8; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; opacity: 0.7 }
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    opacity: root.activeTab === 1 || root.activeTab === 2 ? 1 : 0
                    visible: opacity > 0.01
                    enabled: root.activeTab === 1 || root.activeTab === 2
                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    transform: Translate { y: (root.activeTab === 1 || root.activeTab === 2) ? 0 : 14; Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } } }

                    // Мониторы: одни обои на все или разные на каждом
                    Rectangle {
                        id: monitorsBlock
                        Layout.fillWidth: true
                        Layout.preferredHeight: monitorsCol.implicitHeight + 20
                        visible: root.wallScreens.length > 1
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: 12

                        property string hoverName: ""
                        property int count: Math.max(1, root.wallScreens.length)
                        property real tileW: Math.min(140, (width - 20 - (count - 1) * 34) / count)

                        ColumnLayout {
                            id: monitorsCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: "󰍺"
                                    color: root.walColor13
                                    font.pixelSize: 14
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                                Text {
                                    text: root.wallSplit ? "Разные обои" : "Одни обои"
                                    color: root.walForeground
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                                Item { Layout.fillWidth: true }

                                // Переключатель режима
                                Rectangle {
                                    Layout.preferredHeight: 26
                                    Layout.preferredWidth: modeRow.implicitWidth + 6
                                    radius: 8
                                    color: Qt.rgba(0, 0, 0, 0.25)
                                    Row {
                                        id: modeRow
                                        anchors.centerIn: parent
                                        spacing: 2
                                        Repeater {
                                            model: [
                                                { split: false, icon: "󰌹", label: "Одни" },
                                                { split: true,  icon: "󰌺", label: "Разные" }
                                            ]
                                            delegate: Rectangle {
                                                required property var modelData
                                                property bool active: root.wallSplit === modelData.split
                                                width: segRow.implicitWidth + 16
                                                height: 22
                                                radius: 6
                                                color: active ? Qt.rgba(root.walColor13.r, root.walColor13.g, root.walColor13.b, 0.28)
                                                              : (segMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                Row {
                                                    id: segRow
                                                    anchors.centerIn: parent
                                                    spacing: 5
                                                    Text {
                                                        text: modelData.icon
                                                        color: active ? root.walColor13 : root.walColor8
                                                        font.pixelSize: 11
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                    Text {
                                                        text: modelData.label
                                                        color: active ? root.walForeground : root.walColor8
                                                        font.pixelSize: 11
                                                        font.bold: active
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                }
                                                MouseArea {
                                                    id: segMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.setWallSplit(modelData.split)
                                                        wallSearchInput.forceActiveFocus()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Окошки мониторов слева направо
                            Row {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 0
                                Repeater {
                                    model: root.wallScreens
                                    delegate: Row {
                                        id: monDelegate
                                        required property var modelData
                                        required property int index
                                        property string monName: modelData.name
                                        property bool selected: !root.wallSplit || root.wallTarget === monName
                                        property bool hovered: root.wallSplit ? monitorsBlock.hoverName === monName
                                                                              : monitorsBlock.hoverName !== ""
                                        spacing: 0

                                        // Значок связи между окошками
                                        Item {
                                            visible: monDelegate.index > 0
                                            width: 34
                                            height: monitorsBlock.tileW * 9 / 16
                                            Text {
                                                anchors.centerIn: parent
                                                text: root.wallSplit ? "󰌺" : "󰌹"
                                                color: root.wallSplit ? root.walColor8 : root.walColor13
                                                opacity: root.wallSplit ? 0.5 : 1
                                                font.pixelSize: 16
                                                font.family: "JetBrainsMono Nerd Font"
                                                Behavior on color { ColorAnimation { duration: 200 } }
                                            }
                                        }

                                        Column {
                                            spacing: 0
                                            opacity: monDelegate.selected ? 1 : (monDelegate.hovered ? 0.85 : 0.5)
                                            Behavior on opacity { NumberAnimation { duration: 180 } }

                                            // Экран
                                            Rectangle {
                                                id: screenFrame
                                                width: monitorsBlock.tileW
                                                height: width * (monDelegate.modelData.height / Math.max(1, monDelegate.modelData.width))
                                                radius: 8
                                                color: Qt.rgba(0, 0, 0, 0.4)
                                                border.width: monDelegate.selected ? 2 : 1
                                                border.color: monDelegate.selected ? root.walColor13
                                                             : (monDelegate.hovered ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.15))
                                                Behavior on border.color { ColorAnimation { duration: 180 } }
                                                scale: monDelegate.hovered ? 1.03 : 1
                                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                                Item {
                                                    anchors.fill: parent
                                                    anchors.margins: 3
                                                    Image {
                                                        id: monThumb
                                                        anchors.fill: parent
                                                        source: root.thumbFor(root.monitorWalls[monDelegate.monName] || "")
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                        cache: true
                                                        sourceSize.width: 180
                                                        sourceSize.height: 120
                                                        visible: false
                                                    }
                                                    Rectangle {
                                                        id: monThumbMask
                                                        anchors.fill: parent
                                                        radius: 6
                                                        visible: false
                                                    }
                                                    OpacityMask {
                                                        anchors.fill: parent
                                                        source: monThumb
                                                        maskSource: monThumbMask
                                                        visible: monThumb.status === Image.Ready
                                                    }
                                                    Text {
                                                        anchors.centerIn: parent
                                                        visible: monThumb.status !== Image.Ready
                                                        text: "󰸉"
                                                        color: root.walColor8
                                                        font.pixelSize: 18
                                                        font.family: "JetBrainsMono Nerd Font"
                                                    }
                                                    // Номер монитора
                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.top: parent.top
                                                        anchors.margins: 4
                                                        width: 18; height: 18; radius: 9
                                                        color: monDelegate.selected ? root.walColor13 : Qt.rgba(0, 0, 0, 0.55)
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: monDelegate.index + 1
                                                            color: monDelegate.selected ? root.walBackground : root.walForeground
                                                            font.pixelSize: 10
                                                            font.bold: true
                                                            font.family: "JetBrainsMono Nerd Font"
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onEntered: monitorsBlock.hoverName = monDelegate.monName
                                                    onExited: if (monitorsBlock.hoverName === monDelegate.monName) monitorsBlock.hoverName = ""
                                                    onClicked: {
                                                        if (root.wallSplit) root.wallTarget = monDelegate.monName
                                                        wallSearchInput.forceActiveFocus()
                                                    }
                                                }
                                            }
                                            // Подставка
                                            Rectangle {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: 10; height: 5
                                                color: Qt.rgba(1, 1, 1, 0.15)
                                            }
                                            Rectangle {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: 34; height: 3; radius: 2
                                                color: Qt.rgba(1, 1, 1, 0.15)
                                            }
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                topPadding: 4
                                                text: monDelegate.monName
                                                color: monDelegate.selected && root.wallSplit ? root.walColor13 : root.walColor8
                                                font.pixelSize: 10
                                                font.bold: monDelegate.selected && root.wallSplit
                                                font.family: "JetBrainsMono Nerd Font"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: 12
                        border.width: wallSearchInput.activeFocus ? 1 : 0
                        border.color: root.walColor13
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10
                            Text {
                                text: ""
                                color: root.walColor8
                                font.pixelSize: 14
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            TextInput {
                                id: wallSearchInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                color: root.walForeground
                                font.pixelSize: 14
                                font.family: "JetBrainsMono Nerd Font"
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                clip: true
                                Text {
                                    text: "Search wallpapers..."
                                    color: root.walColor8
                                    visible: !parent.text
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    font: parent.font
                                    opacity: 0.6
                                }
                                onTextChanged: {
                                    root.wallSearchTerm = text.toLowerCase()
                                    root.wallSelectedIndex = 0
                                    wallGridView.contentY = 0
                                }
                                Keys.onPressed: function(event) {
                                    var cols = 3
                                    var total = root.filteredWallpapers.length
                                    var ctrl = (event.modifiers & Qt.ControlModifier)
                                    if (ctrl && event.key === Qt.Key_M && root.wallScreens.length > 1) {
                                        root.setWallSplit(!root.wallSplit)
                                        event.accepted = true
                                        return
                                    }
                                    if (ctrl && root.wallSplit && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                                        var names = root.wallScreens.map(function(s) { return s.name })
                                        var cur = Math.max(0, names.indexOf(root.wallTarget))
                                        cur = event.key === Qt.Key_Right ? Math.min(cur + 1, names.length - 1) : Math.max(cur - 1, 0)
                                        root.wallTarget = names[cur]
                                        event.accepted = true
                                        return
                                    }
                                    if (event.key === Qt.Key_Right) {
                                        root.wallSelectedIndex = Math.min(root.wallSelectedIndex + 1, total - 1)
                                        wallGridView.positionViewAtIndex(root.wallSelectedIndex, GridView.Contain)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Left) {
                                        root.wallSelectedIndex = Math.max(root.wallSelectedIndex - 1, 0)
                                        wallGridView.positionViewAtIndex(root.wallSelectedIndex, GridView.Contain)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Down) {
                                        root.wallSelectedIndex = Math.min(root.wallSelectedIndex + cols, total - 1)
                                        wallGridView.positionViewAtIndex(root.wallSelectedIndex, GridView.Contain)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Up) {
                                        root.wallSelectedIndex = Math.max(root.wallSelectedIndex - cols, 0)
                                        wallGridView.positionViewAtIndex(root.wallSelectedIndex, GridView.Contain)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        if (total > 0 && root.wallSelectedIndex >= 0 && root.wallSelectedIndex < total)
                                            root.applyWallpaper(root.filteredWallpapers[root.wallSelectedIndex])
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Escape) {
                                        root.launcherVisible = false
                                        wallSearchInput.text = ""
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Tab) {
                                        root.wallSelectedIndex = 0
                                        if (root.activeTab === 1) {
                                            root.activeTab = 2
                                        } else {
                                            root.activeTab = 0
                                            searchInput.forceActiveFocus()
                                        }
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
                                        if (total > 0 && root.wallSelectedIndex >= 0 && root.wallSelectedIndex < total)
                                            root.toggleFavorite(root.filteredWallpapers[root.wallSelectedIndex].path)
                                        event.accepted = true
                                    }
                                }
                            }
                            Text {
                                visible: wallSearchInput.text.length > 0
                                text: "󰅖"
                                color: root.walColor8
                                font.pixelSize: 12
                                font.family: "JetBrainsMono Nerd Font"
                                opacity: clearWallMouse.containsMouse ? 1.0 : 0.7
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                                MouseArea {
                                    id: clearWallMouse
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        wallSearchInput.text = ""
                                        wallSearchInput.forceActiveFocus()
                                    }
                                }
                            }
                            // Переключатель бэкенда видео-обоев: mpvpaper / quickshell
                            Rectangle {
                                Layout.preferredHeight: 26
                                Layout.preferredWidth: backendRow.implicitWidth + 16
                                radius: 8
                                color: backendMouse.containsMouse ? Qt.rgba(root.walColor13.r, root.walColor13.g, root.walColor13.b, 0.25)
                                                                  : Qt.rgba(root.walColor13.r, root.walColor13.g, root.walColor13.b, 0.12)
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Row {
                                    id: backendRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: "󰕧"
                                        color: root.walColor13
                                        font.pixelSize: 12
                                        font.family: "JetBrainsMono Nerd Font"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: root.wallBackend === "mpvpaper" ? (root.mpvpaperAvailable ? "mpv" : "mpv ✗") : "qs"
                                        color: root.walForeground
                                        font.pixelSize: 11
                                        font.bold: true
                                        font.family: "JetBrainsMono Nerd Font"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                MouseArea {
                                    id: backendMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.setWallBackend(root.wallBackend === "mpvpaper" ? "quickshell" : "mpvpaper")
                                        wallSearchInput.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: 15
                        clip: true

                        GridView {
                            id: wallGridView
                            anchors.fill: parent
                            anchors.margins: 10
                            cellWidth: Math.floor(width / 3)
                            cellHeight: cellWidth * 0.65 + 30
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true
                            cacheBuffer: 400
                            model: root.filteredWallpapers

                            property real targetContentY: 0
                            property bool animatingScroll: false

                            NumberAnimation {
                                id: wallScrollAnim
                                target: wallGridView
                                property: "contentY"
                                duration: 300
                                easing.type: Easing.OutCubic
                                onFinished: wallGridView.animatingScroll = false
                            }

                            function smoothScrollTo(newY) {
                                var maxY = Math.max(0, contentHeight - height)
                                newY = Math.max(0, Math.min(newY, maxY))
                                if (animatingScroll) {
                                    wallScrollAnim.stop()
                                }
                                animatingScroll = true
                                wallScrollAnim.from = contentY
                                wallScrollAnim.to = newY
                                targetContentY = newY
                                wallScrollAnim.start()
                            }

                            function smoothScrollBy(delta) {
                                var base = animatingScroll ? targetContentY : contentY
                                smoothScrollTo(base + delta)
                            }

                            MouseArea {
                                anchors.fill: parent
                                propagateComposedEvents: true
                                onWheel: function(wheel) {
                                    var step = -wheel.angleDelta.y / 120.0 * (wallGridView.cellHeight * 0.6)
                                    wallGridView.smoothScrollBy(step)
                                }
                                onClicked: function(mouse) { mouse.accepted = false }
                                onPressed: function(mouse) { mouse.accepted = false }
                                onReleased: function(mouse) { mouse.accepted = false }
                            }

                            delegate: Item {
                                width: wallGridView.cellWidth
                                height: wallGridView.cellHeight
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    radius: 10
                                    color: {
                                        if (index === root.wallSelectedIndex)
                                            return Qt.rgba(root.walColor13.r, root.walColor13.g, root.walColor13.b, 0.25)
                                        if (wallItemMouse.containsMouse)
                                            return Qt.rgba(1, 1, 1, 0.08)
                                        return Qt.rgba(0, 0, 0, 0.2)
                                    }
                                    border.width: {
                                        if (modelData.path === root.activeWallpaper) return 2
                                        if (index === root.wallSelectedIndex) return 1
                                        return 0
                                    }
                                    border.color: modelData.path === root.activeWallpaper ? root.walColor2 : root.walColor13
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        spacing: 2
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 7
                                                color: Qt.rgba(0.3, 0.3, 0.3, 0.3)
                                                visible: wallThumbImage.status !== Image.Ready
                                            }
                                            Image {
                                                id: wallThumbImage
                                                anchors.fill: parent
                                                property string thumbHash: (root.wallpaperHashes && root.wallpaperHashes[modelData.path]) ? root.wallpaperHashes[modelData.path] : ""
                                                source: thumbHash ? "file://" + Quickshell.env("HOME") + "/.cache/wallpaper-thumbs/" + thumbHash + ".jpg" : ""
                                                fillMode: Image.PreserveAspectCrop
                                                smooth: false
                                                asynchronous: true
                                                cache: true
                                                sourceSize.width: 180
                                                sourceSize.height: 120
                                                visible: false
                                                onStatusChanged: {
                                                    if (status === Image.Error && modelData.path)
                                                        source = "file://" + modelData.path
                                                }
                                            }
                                            Rectangle {
                                                id: wallThumbMaskRect
                                                anchors.fill: parent
                                                radius: 7
                                                visible: false
                                            }
                                            OpacityMask {
                                                anchors.fill: parent
                                                source: wallThumbImage
                                                maskSource: wallThumbMaskRect
                                            }
                                            Rectangle {
                                                visible: root.isVideo(modelData.path) || root.isScene(modelData.path) || /\.gif$/i.test(modelData.path)
                                                anchors.bottom: parent.bottom
                                                anchors.left: parent.left
                                                anchors.margins: 3
                                                width: badgeText.implicitWidth + 8
                                                height: 14
                                                radius: 4
                                                color: Qt.rgba(0, 0, 0, 0.6)
                                                Text {
                                                    id: badgeText
                                                    anchors.centerIn: parent
                                                    text: root.isScene(modelData.path) ? "✦ scene" : (root.isVideo(modelData.path) ? "▶ video" : "gif")
                                                    color: "white"
                                                    font.pixelSize: 8
                                                    font.bold: true
                                                    font.family: "JetBrainsMono Nerd Font"
                                                }
                                            }
                                            Rectangle {
                                                visible: modelData.path === root.activeWallpaper
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.margins: 3
                                                width: 16
                                                height: 16
                                                radius: 8
                                                color: root.walColor2
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰄬"
                                                    color: root.walBackground
                                                    font.pixelSize: 10
                                                    font.family: "JetBrainsMono Nerd Font"
                                                }
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 22
                                            text: modelData.name
                                            color: {
                                                if (modelData.path === root.activeWallpaper) return root.walColor2
                                                if (index === root.wallSelectedIndex) return root.walColor13
                                                return root.walForeground
                                            }
                                            font.pixelSize: 8
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.bold: index === root.wallSelectedIndex || modelData.path === root.activeWallpaper
                                            elide: Text.ElideMiddle
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                        }
                                    }
                                    MouseArea {
                                        id: wallItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.applyWallpaper(modelData)
                                        onContainsMouseChanged: {
                                            if (containsMouse) root.wallSelectedIndex = index
                                        }
                                    }
                                    // Звёздочка избранного
                                    Rectangle {
                                        property bool fav: root.isFavorite(modelData.path)
                                        visible: fav || wallItemMouse.containsMouse || starMouse.containsMouse
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.margins: 7
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: starMouse.containsMouse ? Qt.rgba(0, 0, 0, 0.8) : Qt.rgba(0, 0, 0, 0.55)
                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.fav ? "★" : "☆"
                                            color: parent.fav ? "#ffcc4d" : "white"
                                            font.pixelSize: 13
                                            font.family: "JetBrainsMono Nerd Font"
                                        }
                                        MouseArea {
                                            id: starMouse
                                            anchors.fill: parent
                                            anchors.margins: -3
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleFavorite(modelData.path)
                                        }
                                    }
                                }
                            }
                            ScrollBar.vertical: ScrollBar {
                                active: true
                                width: 4
                                policy: ScrollBar.AsNeeded
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: root.wallsLoaded && root.filteredWallpapers.length === 0
                            text: root.activeTab === 2 && root.wallFavorites.length === 0
                                  ? "Нет избранных — нажми ☆ на превью"
                                  : "No wallpapers found"
                            color: root.walColor8
                            font.pixelSize: 14
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !root.wallsLoaded && root.wallpaperList.length === 0
                            text: "Loading..."
                            color: root.walColor8
                            font.pixelSize: 13
                            font.family: "JetBrainsMono Nerd Font"
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.4; to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 1.0; to: 0.4; duration: 600; easing.type: Easing.InOutSine }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        color: Qt.rgba(0, 0, 0, 0.3)
                        radius: 10
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            Text { text: "←→↑↓ nav"; color: root.walColor8; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; opacity: 0.7 }
                            Item { Layout.fillWidth: true }
                            Text { text: "↵ apply"; color: root.walColor8; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; opacity: 0.7 }
                            Item { Layout.fillWidth: true }
                            Text { text: "tab apps"; color: root.walColor8; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; opacity: 0.7 }
                            Item { Layout.fillWidth: true }
                            Text { text: "esc close"; color: root.walColor8; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; opacity: 0.7 }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: root
        function onLauncherVisibleChanged() {
            if (root.launcherVisible) {
                searchInput.text = ""
                wallSearchInput.text = ""
                root.selectedIndex = 0
                root.wallSelectedIndex = 0
                appListView.contentY = 0
                wallGridView.contentY = 0
                loadUsageProc.running = true
                currentWallProc.running = true
                focusDelayTimer.start()
            } else {
                searchInput.text = ""
                wallSearchInput.text = ""
                searchInput.focus = false
                wallSearchInput.focus = false
            }
        }
        function onWallSelectedIndexChanged() {
            if (root.activeTab === 1)
                wallGridView.positionViewAtIndex(root.wallSelectedIndex, GridView.Contain)
        }
    }

    Timer {
        id: focusDelayTimer
        interval: 50
        repeat: false
        onTriggered: {
            launcherPanel.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive
            exclusiveReleaseTimer.start()
        }
    }

    Timer {
        id: exclusiveReleaseTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (root.activeTab === 0)
                searchInput.forceActiveFocus()
            else {
                if (!root.wallsLoaded) root.loadWallpapers()
                wallSearchInput.forceActiveFocus()
            }
            launcherPanel.WlrLayershell.keyboardFocus = WlrKeyboardFocus.OnDemand
        }
    }
}