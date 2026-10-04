import QtQuick

// Keep one cached atlas texture and move its viewport for each pose. No source
// change or clip-region decoding is needed during a pitch.
Item {
    id: sprite
    property var rows: null
    property real px: 4
    readonly property int cell: Math.max(1, Math.round(px))
    readonly property var frame: rows || {x:0,y:20,w:384,h:330}
    width: 40 * cell
    height: 40 * cell
    clip: true
    Image {
        source: "../assets/players.png"
        width: 1536 * sprite.width / sprite.frame.w
        height: 1024 * sprite.height / sprite.frame.h
        x: -sprite.frame.x * sprite.width / sprite.frame.w
        y: -sprite.frame.y * sprite.height / sprite.frame.h
        smooth: false
        mipmap: false
        cache: true
    }
}
