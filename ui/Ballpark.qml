import QtQuick

// Fixed illustrated park layer. Geometry/style changes repaint this canvas;
// the pitch clock, score and moving actors never invalidate it.
Canvas {
    id: park
    property real unit: 8
    property real cx: width / 2
    property real homeY: height * 0.85
    property real base: width / 5
    property real fieldTop: 0
    property real fieldBottom: height
    property real perspective: 0.62
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onBaseChanged: requestPaint()
    onHomeYChanged: requestPaint()
    onFieldTopChanged: requestPaint()
    onFieldBottomChanged: requestPaint()
    onVisibleChanged: requestPaint()
    function px(d,e) { return cx + (d-e)*base }
    function py(d,e) { return homeY - (d+e)*base*perspective }
    function wall(phi) { return 2.75 / (Math.cos(phi) + Math.sin(phi)) }
    onPaint: {
        var c=getContext("2d"); c.reset()
        if (base<=0) return
        c.save(); c.beginPath();c.rect(0,fieldTop,width,fieldBottom-fieldTop);c.clip()
        var u=unit, horizon=fieldTop+u*6, wallTop=homeY-2.75*base*perspective
        var i, phi, r
        // Fence panels and a white outfield, with restrained grass stipple.
        c.beginPath();c.moveTo(px(0,0),py(0,0))
        for(i=0;i<=64;i++){phi=i/64*Math.PI/2;r=wall(phi);c.lineTo(px(r*Math.cos(phi),r*Math.sin(phi)),py(r*Math.cos(phi),r*Math.sin(phi)))}
        c.closePath();c.fillStyle="#E8E8E8";c.fill();c.save();c.clip()
        c.fillStyle="#5A5A5A"
        var noise=7331
        for(i=0;i<650;i++) {
            noise=(noise*1664525+1013904223)>>>0
            var gx=noise/4294967296*width
            noise=(noise*1664525+1013904223)>>>0
            var gy=fieldTop+noise/4294967296*(fieldBottom-fieldTop)
            // Open dirt around the plate, pitcher, and bases.
            var dist=Math.hypot((gx-cx)/base,(homeY-gy)/(base*perspective))
            if(dist>1.6)c.fillRect(Math.round(gx),Math.round(gy),Math.max(1,u*0.2),Math.max(1,u*0.2))
        }
        c.restore()
        c.strokeStyle="black";c.lineWidth=Math.max(3,u*0.45)
        c.beginPath()
        for(i=0;i<=48;i++) {
            phi=i/48*Math.PI/2;r=wall(phi)
            var wx=px(r*Math.cos(phi),r*Math.sin(phi)),wy=py(r*Math.cos(phi),r*Math.sin(phi))
            if(i===0)c.moveTo(wx,wy);else c.lineTo(wx,wy)
        }
        c.stroke()
        // Broad white infield dirt gives the park a readable printed-LCD silhouette.
        c.beginPath();c.moveTo(cx,homeY)
        for(i=0;i<=48;i++) {
            phi=i/48*Math.PI/2
            c.lineTo(px(1.45*Math.cos(phi),1.45*Math.sin(phi)),py(1.45*Math.cos(phi),1.45*Math.sin(phi)))
        }
        c.closePath();c.fillStyle="white";c.fill()
        // Fine, fixed turf marks leave a clean dirt path around the bases.
        c.save();c.beginPath()
        c.moveTo(px(0.15,0.15),py(0.15,0.15));c.lineTo(px(0.85,0.15),py(0.85,0.15))
        c.lineTo(px(0.85,0.85),py(0.85,0.85));c.lineTo(px(0.15,0.85),py(0.15,0.85));c.closePath();c.fillStyle="#E8E8E8";c.fill();c.clip()
        c.fillStyle="#5A5A5A"
        for(var ty=py(1,1);ty<homeY;ty+=u*1.7)
            for(var tx=cx-base;tx<cx+base;tx+=u*2.2)
                c.fillRect(Math.round(tx),Math.round(ty),Math.max(1,u*0.18),Math.max(1,u*0.18))
        c.restore()
        c.restore()
    }
    Item {
        x: 0; y: park.fieldTop
        width: park.width
        height: Math.max(1,park.homeY - 2.75 * park.base * park.perspective - park.fieldTop)
        clip: true
        Image {
            // Remove only blank top/bottom margins through a runtime viewport.
            source: "../assets/ballpark.png"
            sourceClipRect: Qt.rect(0,190,2172,442)
            anchors.fill: parent
            smooth: false
        }
    }

}
