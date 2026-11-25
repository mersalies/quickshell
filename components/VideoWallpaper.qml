import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtMultimedia

// Видео-обои силами quickshell: по окну на каждый монитор на слое Bottom
// (над awww, под окнами). Видео для монитора берётся из root.videoWalls[имя монитора].
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: wallWin
        required property var modelData
        screen: modelData
        property string videoPath: root.videoWalls[modelData.name] || ""

        visible: videoPath !== ""
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell-wallpaper"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }
        mask: Region {}   // клики проходят насквозь

        // Пауза, когда обои закрыты полноэкранным окном
        property var hyprMonitor: Hyprland.monitorFor(modelData)
        property bool covered: hyprMonitor && hyprMonitor.activeWorkspace
                               ? hyprMonitor.activeWorkspace.hasFullscreen : false
        property bool shouldPlay: visible && !covered

        Video {
            id: video
            anchors.fill: parent
            source: wallWin.videoPath !== "" ? "file://" + wallWin.videoPath : ""
            loops: MediaPlayer.Infinite
            muted: true
            fillMode: VideoOutput.PreserveAspectCrop
            autoPlay: false
            opacity: playbackState === MediaPlayer.PlayingState || playbackState === MediaPlayer.PausedState ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

            onSourceChanged: if (source != "" && wallWin.shouldPlay) play()
        }

        onShouldPlayChanged: shouldPlay ? video.play() : video.pause()
        Component.onCompleted: if (shouldPlay) video.play()
    }
}
