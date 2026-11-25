import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: powerPanel
    visible: true
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins { top: 40; right: root.powerVisible ? 6 : -300 }
    implicitHeight: 210
    implicitWidth: 240
    color: "transparent"
    focusable: true
    WlrLayershell.keyboardFocus: root.powerVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    Behavior on margins.right { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    readonly property var profiles: ["performance", "balanced", "power-saver"]
    readonly property var profileIcons: ({
        "performance": "󰓅",
        "balanced": "󰗑",
        "power-saver": "󰌪"
    })
    readonly property var profileLabels: ({
        "performance": "Performance",
        "balanced": "Balanced",
        "power-saver": "Power Saver"
    })
    readonly property var profileColors: ({
        "performance": root.walColor1,
        "balanced": root.walColor5,
        "power-saver": root.walColor2
    })

    Item {
        anchors.fill: parent
        focus: root.powerVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.powerVisible = false
                event.accepted = true
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(root.walBackground.r, root.walBackground.g, root.walBackground.b, 0.7)
            radius: 20

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "󰢮"
                        color: root.walColor5
                        font.pixelSize: 20
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        text: "Power Profile"
                        color: root.walColor5
                        font.pixelSize: 16
                        font.bold: true
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Item { Layout.fillWidth: true }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Qt.rgba(0, 0, 0, 0.3)
                    radius: 12
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        Repeater {
                            model: powerPanel.profiles
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: 10
                                property bool isActive: modelData === root.activePowerProfile
                                color: profileMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    Text {
                                        text: powerPanel.profileIcons[modelData]
                                        color: powerPanel.profileColors[modelData]
                                        font.pixelSize: 16
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                    Text {
                                        text: powerPanel.profileLabels[modelData]
                                        color: root.walForeground
                                        font.pixelSize: 13
                                        font.family: "JetBrainsMono Nerd Font"
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        visible: parent.parent.isActive
                                        text: "󰄬"
                                        color: root.walColor2
                                        font.pixelSize: 13
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                }

                                MouseArea {
                                    id: profileMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setPowerProfile(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: root
        function onPowerVisibleChanged() {
            if (root.powerVisible) {
                powerFocusTimer.start()
            }
        }
    }

    Timer {
        id: powerFocusTimer
        interval: 50
        repeat: false
        onTriggered: {
            powerPanel.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive
            powerReleaseTimer.start()
        }
    }

    Timer {
        id: powerReleaseTimer
        interval: 100
        repeat: false
        onTriggered: {
            powerPanel.WlrLayershell.keyboardFocus = WlrKeyboardFocus.OnDemand
        }
    }
}
