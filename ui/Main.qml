import QtQuick

// AppLoad frontend. There is no backend: the game is pure QML, so nothing has
// to cross the socket and no SDK binary is needed.
Item {
    id: root
    anchors.fill: parent

    // AppLoad closes the app when this fires.
    signal close
    property var refreshComponent: null
    property var refreshArea: null
    property bool refreshUnavailable: false
    function clearRefresh() {
        if (refreshArea) { refreshArea.destroy(); refreshArea = null }
    }
    function updateRefresh() {
        var wanted = visible && game.animating && !game.paused && game.smoothMotion
        if (!wanted) { clearRefresh(); return }
        if (refreshArea || refreshUnavailable) return
        if (!refreshComponent) refreshComponent = Qt.createComponent("RefreshArea.qml")
        if (refreshComponent.status === Component.Ready) {
            refreshArea = refreshComponent.createObject(game.animationSurface)
            if (!refreshArea) refreshUnavailable = true
        } else if (refreshComponent.status === Component.Error) {
            refreshUnavailable = true
            console.warn("Pocket Diamond: display helper unavailable; using standard refresh", refreshComponent.errorString())
        }
    }
    function unloading() { game.suspend(); clearRefresh() }
    onVisibleChanged: updateRefresh()
    Component.onDestruction: clearRefresh()
    Connections {
        target: game
        function onAnimatingChanged() { root.updateRefresh() }
        function onPausedChanged() { root.updateRefresh() }
        function onSmoothMotionChanged() { root.updateRefresh() }
    }

    Game {
        id: game
        anchors.fill: parent
        onQuit: root.close()
    }
}
