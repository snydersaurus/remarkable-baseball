import QtQuick

// Outlined text button. Acts on press, not release: on this panel every
// millisecond before the redraw starts is felt. A selected button is filled
// black with white type; a disabled one is faded and ignores taps.
Rectangle {
    id: btn
    property string label
    property string sub: ""
    property real fontSize: 28
    property bool selected: false
    property bool primary: false
    signal tapped

    color: selected ? "black" : "white"
    border.color: "black"
    border.width: Math.max(3, Math.round(fontSize * (primary ? 0.065 : 0.085)))
    radius: Math.round(fontSize * 0.22)
    opacity: 1
    Rectangle {
        anchors.fill: parent; anchors.margins: Math.max(7, btn.fontSize * 0.2)
        color: "transparent"; radius: Math.max(2, btn.radius * 0.55)
        border.color: btn.selected ? "white" : "black"
        border.width: Math.max(1, Math.round(btn.fontSize * 0.035))
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 2 * btn.border.width - 8
        spacing: Math.round(btn.fontSize * (btn.primary ? 0.4 : 0.1))
        Canvas {
            visible: btn.primary
            anchors.horizontalCenter: parent.horizontalCenter
            width: btn.fontSize * 2.7; height: visible ? width : 0
            onWidthChanged: requestPaint()
            onPaint: {
                var c=getContext("2d");c.reset();c.scale(width/100,height/100)
                c.strokeStyle="black";c.fillStyle="white";c.lineCap="round"
                // Crossed bats and stitched ball: a printed handheld emblem.
                c.lineWidth=9;c.beginPath();c.moveTo(16,15);c.lineTo(78,81);c.stroke()
                c.beginPath();c.moveTo(84,15);c.lineTo(22,81);c.stroke()
                c.strokeStyle="white";c.lineWidth=3;c.beginPath();c.moveTo(16,15);c.lineTo(78,81);c.stroke()
                c.beginPath();c.moveTo(84,15);c.lineTo(22,81);c.stroke()
                c.strokeStyle="black";c.lineWidth=3
                c.beginPath();c.arc(50,47,29,0,Math.PI*2);c.fill();c.stroke()
                c.lineWidth=1.8
                for(var side=-1;side<=1;side+=2) {
                    c.beginPath();c.moveTo(50+side*15,22)
                    c.bezierCurveTo(50+side*4,35,50+side*4,58,50+side*15,72);c.stroke()
                    for(var i=0;i<5;i++) {
                        var y=29+i*9, x=50+side*(8+Math.pow((y-47)/25,2)*6)
                        c.beginPath();c.moveTo(x-3,y-2);c.lineTo(x+3,y+2);c.stroke()
                    }
                }
            }
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 14
            text: btn.label
            font.pixelSize: btn.fontSize
            font.bold: true
            font.family: "monospace"
            font.letterSpacing: btn.fontSize * 0.06
            color: btn.selected ? "white" : "black"
        }
        Text {
            visible: btn.sub !== ""
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 12
            text: btn.sub
            font.pixelSize: Math.round(btn.fontSize * 0.5)
            font.bold: true
            color: btn.selected ? "white" : "black"
        }
    }
    MouseArea {
        anchors.fill: parent
        onPressed: btn.tapped()
    }
}
