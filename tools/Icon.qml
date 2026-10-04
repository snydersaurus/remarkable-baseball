import QtQuick
import QtQuick.Window
import "../ui"
import "../ui/Sprites.mjs" as Art

// Renders the 600px launcher icon from the game's own batter, inside the
// handheld's screen frame:   qml tools/Icon.qml   (run by tools/make-icon.sh)
Window {
    width: 600
    height: 600
    visible: true
    color: "white"

    Item {
        id: art
        anchors.fill: parent
        Rectangle { anchors.fill: parent; color: "white" }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 18
            radius: 50
            color: "black"
            Rectangle {
                anchors.fill: parent
                anchors.margins: 16
                radius: 22
                color: "white"
                PixelSprite {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: -10
                    rows: Art.BATTER_STANCE
                    px: 13
                }
            }
        }
    }

    Timer {
        interval: 800; running: true
        onTriggered: art.grabToImage(function (r) {
            r.saveToFile("appload-native/icon.png")
            console.log("wrote appload-native/icon.png")
            Qt.quit()
        })
    }
}
