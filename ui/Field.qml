import QtQuick
import "Baseball.mjs" as B
import "Sprites.mjs" as Art

// The handheld's screen: scoreboard, the diamond seen from behind home, the
// strike-zone inset, the result banner and the play-by-play line. Also the
// title and final-score screens, which take over the same frame.
//
// The park is a cached drawing. Moving sprites and the ball are independent
// items, stepped by Game; the scoreboard observes only committed rules state.
Item {
    id: field

    property alias animationSurface: refreshRegion
    Item {
        id: refreshRegion
        x: 0; y: field.fieldTop
        width: field.width; height: field.fieldBottom - field.fieldTop
    }

    property var motion: null
    property var motionEvent: null
    property bool deliveryActive: false
    property int swingFrame: -1
    property bool paused: false
    property bool holdingContact: false
    readonly property var event: motion ? motionEvent : last
    property var st
    property int rev: 0
    property string mode: "title"      // "title", "play" or "final"
    property real u: 10

    // The latest event, read through rev so bindings notice in-place changes.
    readonly property var last: rev >= 0 && st && !motion ? st.last : null
    readonly property bool userBats: rev >= 0 && st ? B.userBatting(st) : true
    readonly property real fs: Math.round(u * 3.2)

    function teamName(t) {
        return st && t === st.userTeam ? "YOU" : "CPU"
    }

    // ------------------------------------------------------------ geometry

    readonly property real boardH: Math.round(Math.max(u * 10, height * 0.13))
    readonly property bool landscape: width > height
    readonly property real msgH: Math.round(landscape ? Math.max(u * 9.5, height * 0.12) : u * 13)
    readonly property real fieldTop: boardH
    readonly property real fieldBottom: height - msgH
    // a: the distance between bases, across the screen. k flattens the
    // diamond into perspective.
    readonly property real k: landscape ? 0.62 : 1.02
    readonly property real a: Math.floor(Math.min((fieldBottom - fieldTop - u * 14) / (2.75 * k + 0.36), width / 3.65))
    readonly property real cx: Math.round(width / 2)
    readonly property real homeY: Math.round(fieldBottom - 0.36 * a)

    // A point on the field from diamond coordinates: d along the first-base
    // line and e along the third-base line, in base lengths.
    function px(d, e) { return cx + (d - e) * a }
    function py(d, e) { return homeY - (d + e) * a * k }
    // The outfield wall, phi 0 down the right-field line to 90 down the left.
    function wall(phi) { return 2.75 / (Math.cos(phi) + Math.sin(phi)) }

    // Where a ball put in play ended up, from its spray (0 the third-base
    // line, 1 the first) and how far that kind of hit carries.
    function ballSpot(e) {
        var phi = (1 - e.spray) * Math.PI / 2
        var depth = { groundout: 0.85, single: 1.55, double: 2.05, triple: 2.3,
                      flyout: 1.75, foul: 1.25 }[e.kind]
        if (e.bunt) depth = 0.38
        if (e.kind === "homer") depth = wall(phi) + 0.28
        return [px(depth * Math.cos(phi), depth * Math.sin(phi)),
                py(depth * Math.cos(phi), depth * Math.sin(phi))]
    }

    readonly property bool contact: last !== null && last.kind !== "ball" && last.kind !== "called"
                                     && last.kind !== "whiff"

    // ------------------------------------------------------------ the field

    Ballpark {
        anchors.fill: parent
        visible: field.mode === "play"
        unit: field.u; cx: field.cx; homeY: field.homeY; base: field.a
        fieldTop: field.fieldTop; fieldBottom: field.fieldBottom; perspective: field.k
    }

    Canvas {
        id: diamond
        anchors.fill: parent
        visible: field.mode === "play"
        property int rev: field.rev
        onRevChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            if (!field.st || field.a <= 0)
                return
            var f = field, a = f.a, u = f.u
            ctx.lineJoin = "round"
            ctx.lineCap = "round"

            // Outfield wall: a heavy line, a lighter warning track inside it.
            var steps = 40, i, phi, r
            ctx.strokeStyle = "black"
            ctx.lineWidth = Math.max(4, u * 0.6)
            ctx.beginPath()
            for (i = 0; i <= steps; i++) {
                phi = i / steps * Math.PI / 2
                r = f.wall(phi)
                var wx = f.px(r * Math.cos(phi), r * Math.sin(phi))
                var wy = f.py(r * Math.cos(phi), r * Math.sin(phi))
                if (i === 0) ctx.moveTo(wx, wy); else ctx.lineTo(wx, wy)
            }
            ctx.stroke()
            ctx.strokeStyle = "#5A5A5A"
            ctx.lineWidth = Math.max(2, u * 0.22)
            ctx.beginPath()
            for (i = 0; i <= steps; i++) {
                phi = i / steps * Math.PI / 2
                r = f.wall(phi) - 0.14
                var tx = f.px(r * Math.cos(phi), r * Math.sin(phi))
                var ty = f.py(r * Math.cos(phi), r * Math.sin(phi))
                if (i === 0) ctx.moveTo(tx, ty); else ctx.lineTo(tx, ty)
            }
            ctx.stroke()

            // Infield grass edge.
            ctx.beginPath()
            for (i = 0; i <= steps; i++) {
                phi = i / steps * Math.PI / 2
                r = 1.45
                var gx = f.px(r * Math.cos(phi), r * Math.sin(phi))
                var gy = f.py(r * Math.cos(phi), r * Math.sin(phi))
                if (i === 0) ctx.moveTo(gx, gy); else ctx.lineTo(gx, gy)
            }
            ctx.stroke()

            // Foul lines, then the base paths.
            ctx.strokeStyle = "black"
            ctx.lineWidth = Math.max(2, u * 0.27)
            ctx.beginPath()
            ctx.moveTo(f.px(0, 0), f.py(0, 0))
            ctx.lineTo(f.px(f.wall(0), 0), f.py(f.wall(0), 0))
            ctx.moveTo(f.px(0, 0), f.py(0, 0))
            ctx.lineTo(f.px(0, f.wall(Math.PI / 2)), f.py(0, f.wall(Math.PI / 2)))
            ctx.moveTo(f.px(1, 0), f.py(1, 0))
            ctx.lineTo(f.px(1, 1), f.py(1, 1))
            ctx.lineTo(f.px(0, 1), f.py(0, 1))
            ctx.stroke()

            // The mound.
            ctx.strokeStyle = "#5A5A5A"
            ctx.lineWidth = Math.max(2, u * 0.25)
            ctx.beginPath()
            ctx.ellipse(f.px(0.5, 0.5) - a * 0.16, f.py(0.5, 0.5) - a * 0.16 * f.k,
                        a * 0.32, a * 0.32 * f.k)
            ctx.stroke()

            // Bases, filled when someone is on.
            var bases = [[1, 0], [1, 1], [0, 1]]
            var bs = Math.max(8, a * 0.1)
            for (i = 0; i < 3; i++) {
                var bx = f.px(bases[i][0], bases[i][1]), by = f.py(bases[i][0], bases[i][1])
                ctx.beginPath()
                ctx.moveTo(bx, by - bs * f.k)
                ctx.lineTo(bx + bs, by)
                ctx.lineTo(bx, by + bs * f.k)
                ctx.lineTo(bx - bs, by)
                ctx.closePath()
                ctx.fillStyle = field.st.bases[i] ? "black" : "white"
                ctx.fill()
                ctx.strokeStyle = "black"
                ctx.lineWidth = Math.max(3, u * 0.3)
                ctx.stroke()
            }

            // Batter's boxes: quiet chalk outlines around the action.
            ctx.strokeStyle = "#5A5A5A"
            ctx.lineWidth = Math.max(2,u*0.22)
            ctx.strokeRect(f.cx-a*0.34,f.homeY-a*0.25,a*0.2,a*0.29)
            ctx.strokeRect(f.cx+a*0.14,f.homeY-a*0.25,a*0.2,a*0.29)
            ctx.strokeStyle = "black"
            // Home plate.
            var hx = f.px(0, 0), hy = f.py(0, 0), hs = bs * 1.1
            ctx.beginPath()
            ctx.moveTo(hx - hs, hy - hs * 0.5)
            ctx.lineTo(hx + hs, hy - hs * 0.5)
            ctx.lineTo(hx + hs, hy + hs * 0.1)
            ctx.lineTo(hx, hy + hs * 0.6)
            ctx.lineTo(hx - hs, hy + hs * 0.1)
            ctx.closePath()
            ctx.fillStyle = "white"
            ctx.fill()
            ctx.stroke()

        }
    }

    // Paths are calculated in field space, but only these small items move.
    function pitchPoint(t) {
        var e = event
        var side = e ? (e.x - 1.5) / 1.5 * a * 0.12 : 0
        if (e && !e.inZone) side = (e.loc === "in" ? -1 : 1) * a * 0.42
        var bend = e && e.pitch === "curve" ? Math.sin(t * Math.PI) * a * 0.15 : 0
        return [cx + side * t * t + bend,
                py(0.5,0.5) - u * 3 + (homeY - u * 4.5 - py(0.5,0.5) + u * 3) * t]
    }
    function hitPoint(t) {
        if (!event) return [cx, homeY]
        var end = ballSpot(event)
        var lift = event.kind === "groundout" || event.bunt ? 0 : Math.sin(t * Math.PI) * a * 0.4
        return [cx + (end[0] - cx) * t, homeY - u * 4.5 + (end[1] - homeY + u * 4.5) * t - lift]
    }
    function runnerPoint(r) {
        var places = [[0,0],[1,0],[1,1],[0,1],[0,0]]
        var distance = r.from + (r.to - r.from) * r.t
        var lo = Math.min(3, Math.floor(distance)), amount = distance - lo
        var d = places[lo][0] + (places[lo+1][0] - places[lo][0]) * amount
        var e = places[lo][1] + (places[lo+1][1] - places[lo][1]) * amount
        return [px(d,e), py(d,e)]
    }
    readonly property var visibleBall: motion ? motion.ball : event ?
        { space: contact ? "hit" : "catch", t: 1 } : null
    function ballPoint(t) {
        if (visibleBall && visibleBall.space === "catch") return [pitchPoint(1)[0], homeY + u]
        return visibleBall && visibleBall.space === "hit" ? hitPoint(t) : pitchPoint(t)
    }

    // A quiet plate target lights during the forgiving contact window.
    Rectangle {
        visible: field.mode === "play" && field.deliveryActive && field.motion && field.motion.ball && field.motion.ball.t >= 0.6
        x: field.cx - field.u * 3.5
        y: field.homeY - field.u * 6.4
        width: field.u * 7; height: field.u * 3.8
        color: "transparent"; radius: field.u * 1.9
        border.color: "black"; border.width: Math.max(2,field.u * 0.25)
    }

    // ------------------------------------------------------------ players

    Item {
        anchors.fill: parent
        visible: field.mode === "play"

        PixelSprite {
            id: pitcher
            px: field.u * 0.30
            rows: !field.motion ? Art.PITCHER_SET
                : field.motion.pitcher === "windup" ? Art.PITCHER_WINDUP
                : field.motion.pitcher === "release" ? Art.PITCHER_THROW
                : field.motion.pitcher === "follow" ? Art.PITCHER_FOLLOW : Art.PITCHER_SET
            x: Math.round(field.px(0.5,0.5) - width/2)
            y: Math.round(field.py(0.5,0.5) - height + field.a*0.06)
        }
        PixelSprite {
            px: field.u * 0.34
            rows: Art.CATCHER
            x: Math.round(field.cx - width/2)
            y: Math.round(field.homeY + field.a*0.3 - height)
        }
        PixelSprite {
            px: field.u * 0.43
            visible: !field.motion || field.motion.batter !== "empty"
            readonly property string pose: field.deliveryActive ?
                (field.holdingContact || field.swingFrame === 0 ? "swing" : field.swingFrame > 0 ? "follow" : "stance")
                : field.motion ? field.motion.batter : "stance"
            rows: pose === "load" ? Art.BATTER_LOAD : pose === "swing" ? Art.BATTER_SWING
                : pose === "follow" ? Art.BATTER_FOLLOW : pose === "bunt" ? Art.BATTER_BUNT : Art.BATTER_STANCE
            x: Math.round(field.cx - width * 0.98)
            y: Math.round(field.homeY + field.a*0.08 - height)
        }
        // Static defenders make the diamond read as a ballpark, not a diagram.
        Repeater {
            model: [[0.25,1.05],[1.05,0.25],[1.15,1.15]]
            PixelSprite {
                px: field.u * 0.25
                rows: Art.FIELDER
                x: Math.round(field.px(modelData[0],modelData[1])-width/2)
                y: Math.round(field.py(modelData[0],modelData[1])-height)
            }
        }
        Repeater {
            model: field.motion ? field.motion.runners : field.st && field.rev >= 0 ?
                field.st.bases.map(function(on,i) { return {from:i+1,to:i+1,t:0,on:on} }).filter(function(r) {return r.on}) : []
            PixelSprite {
                readonly property var at: field.runnerPoint(modelData)
                visible: !(modelData.to === 4 && modelData.t >= 1)
                px: field.u * 0.25
                rows: field.motion && field.motion.stride ? Art.RUNNER_ALT : Art.RUNNER
                x: Math.round(at[0]-width/2)
                y: Math.round(at[1]-height-field.u)
            }
        }
        Repeater {
            model: field.visibleBall && field.visibleBall.space !== "catch" ? 2 : 0
            Rectangle {
                readonly property real t: Math.max(0, field.visibleBall.t - (index+1)*0.15)
                readonly property var at: field.ballPoint(t)
                width: Math.max(3,Math.round(field.u*0.4)); height: width
                x: Math.round(at[0]-width/2); y: Math.round(at[1]-height/2)
                color: "black"
                visible: field.visibleBall && field.visibleBall.t > (index+1)*0.15
            }
        }
        Rectangle {
            visible: field.visibleBall !== null
            readonly property var at: field.visibleBall ? field.ballPoint(field.visibleBall.t) : [0,0]
            width: Math.round(field.u*2.5); height: width; radius: width/2
            x: Math.round(at[0]-width/2); y: Math.round(at[1]-height/2)
            color: "white"; border.color: "black"
            border.width: Math.max(3,Math.round(field.u*0.35))
        }
    }

    // ------------------------------------------------------------ zone inset

    Item {
        id: zone
        Rectangle { anchors.fill: parent; color: "white" }
        visible: field.mode === "play" && !field.userBats
        readonly property real box: Math.round(Math.min(field.width * (field.landscape ? 0.11 : 0.16), (field.fieldBottom - field.fieldTop) * 0.27))
        readonly property real pad: Math.round(box * 0.28)
        width: box + 2 * pad
        height: box * 1.2 + 2 * pad + label.height + caption.height
        // Landscape has room in the corner beside home plate; portrait has it
        // above the right-field wall.
        x: field.width - width - Math.round(field.u * 1.2)
        y: field.landscape ? field.fieldBottom - height - Math.round(field.u * 0.8)
                           : field.fieldTop + Math.round(field.u * 1.2)

        Text {
            id: label
            anchors.horizontalCenter: parent.horizontalCenter
            text: "ZONE"
            font.pixelSize: Math.round(field.fs * 0.7)
            font.bold: true
            font.family: "monospace"
            font.letterSpacing: field.u * 0.3
        }
        Item {
            id: zoneArea
            anchors.top: label.bottom
            width: parent.width
            height: zone.box * 1.2 + 2 * zone.pad
            Rectangle {
                id: zoneBox
                x: zone.pad; y: zone.pad
                width: zone.box; height: zone.box * 1.2
                color: "white"
                border.color: "black"
                border.width: Math.max(3, Math.round(field.u * 0.35))
                Repeater {
                    model: 2
                    Rectangle {
                        x: Math.round(zoneBox.width * (index + 1) / 3 - width / 2)
                        y: zoneBox.border.width
                        width: Math.max(2, Math.round(field.u * 0.2))
                        height: zoneBox.height - 2 * zoneBox.border.width
                        color: "#5A5A5A"
                    }
                }
            }
            Rectangle {
                visible: field.last !== null
                width: Math.round(field.u * 2.2); height: width; radius: width / 2
                x: field.last ? Math.round(zoneBox.x + field.last.x / 3 * zoneBox.width - width / 2) : 0
                y: field.last ? Math.round(zoneBox.y + field.last.y / 3 * zoneBox.height - height / 2) : 0
                color: "black"
                border.color: "white"
                border.width: Math.max(2, Math.round(field.u * 0.25))
            }
        }
        Row {
            anchors.top: zoneArea.bottom
            anchors.topMargin: -zone.pad * 0.6
            x: zone.pad
            Repeater {
                model: ["IN", "MID", "OUT"]
                Text {
                    width: zone.box / 3
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.pixelSize: Math.round(field.fs * 0.55)
                    font.bold: true
            font.family: "monospace"
                }
            }
        }
        Text {
            id: caption
            anchors.top: zoneArea.bottom
            anchors.topMargin: Math.round(field.fs * 0.2)
            anchors.horizontalCenter: parent.horizontalCenter
            text: field.last ? B.pitchById(field.last.pitch).short : " "
            font.pixelSize: Math.round(field.fs * 0.7)
            font.bold: true
            font.family: "monospace"
        }
    }

    // ------------------------------------------------------------ banner

    Rectangle {
        id: banner
        visible: field.mode === "play" && (field.last !== null || (field.st && field.st.phase !== "play"))
        readonly property string headline: !field.st ? ""
            : field.st.phase === "final" ? "GAME OVER"
            : field.st.phase === "switch" ? "SIDE RETIRED"
            : field.last ? field.last.headline : ""
        readonly property bool big: field.st && (field.st.phase !== "play"
            || (field.last && ["single", "double", "triple", "homer"].indexOf(field.last.kind) >= 0)
            || (field.last && (field.last.strikeout || field.last.walk)))
        x: Math.round(field.u * 1.2)
        y: field.fieldTop + Math.round(field.u * 1.2)
        width: Math.min(bannerText.implicitWidth + field.u * 4, field.width * 0.36)
        height: Math.round(field.fs * (big ? 2.4 : 1.9))
        color: big ? "black" : "white"
        border.color: "black"
        border.width: Math.max(3, Math.round(field.u * 0.45))
        radius: Math.round(field.u * 0.6)
        Text {
            id: bannerText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, field.width * 0.36 - field.u * 3)
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 12
            text: banner.headline
            color: banner.big ? "white" : "black"
            font.pixelSize: Math.round(field.fs * (banner.big ? 1.45 : 1.15))
            font.bold: true
            font.family: "monospace"
            font.letterSpacing: field.u * 0.25
        }
    }

    // ------------------------------------------------------------ scoreboard

    Item {
        id: board
        visible: field.mode !== "title"
        width: parent.width
        height: field.boardH

        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round(field.u * 1.5)
            spacing: Math.round(field.u * 2.2)

            Repeater {
                model: 2
                Row {
                    spacing: Math.round(field.u * 1)
                    anchors.verticalCenter: parent.verticalCenter
                    // The batting side gets a solid diamond.
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(field.u * 1.6); height: width
                        rotation: 45
                        color: field.rev >= 0 && field.st && field.st.half === index && field.mode === "play"
                               ? "black" : "white"
                        border.color: "black"
                        border.width: Math.max(2, Math.round(field.u * 0.3))
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: field.teamName(index)
                            font.pixelSize: Math.round(field.fs * (field.landscape ? 0.95 : 0.8))
                            font.bold: true
            font.family: "monospace"
                        }
                        Text {
                            text: index === 0 ? "VISITORS" : "HOME"
                            font.pixelSize: Math.round(field.fs * 0.5)
                            font.bold: true
            font.family: "monospace"
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: field.rev >= 0 && field.st ? field.st.score[index] : "0"
                        font.pixelSize: Math.round(field.fs * 2)
                        font.bold: true
            font.family: "monospace"
                    }
                }
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Math.round(field.u * 1.5)
            spacing: Math.round(field.u * 2.2)
            visible: field.mode === "play"

            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: field.st && field.st.half === 0 ? "TOP" : "BOT"
                    font.pixelSize: Math.round(field.fs * 0.6)
                    font.bold: true
            font.family: "monospace"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: field.rev >= 0 && field.st ? field.st.inning : "1"
                    font.pixelSize: Math.round(field.fs * 1.3)
                    font.bold: true
            font.family: "monospace"
                }
            }
            Repeater {
                // Balls, strikes, outs: label and pips.
                model: [["B", 3], ["S", 2], ["O", 2]]
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(field.u * 0.6)
                    readonly property int lit: !field.st || field.rev < 0 ? 0
                        : index === 0 ? field.st.balls : index === 1 ? field.st.strikes
                        : Math.min(2, field.st.outs)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData[0]
                        font.pixelSize: Math.round(field.fs * (field.landscape ? 0.95 : 0.8))
                        font.bold: true
            font.family: "monospace"
                    }
                    Repeater {
                        model: modelData[1]
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(field.u * 2.3); height: width; radius: width / 2
                            color: index < parent.lit ? "black" : "white"
                            border.color: "black"
                            border.width: Math.max(3, Math.round(field.u * 0.35))
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Math.max(3, Math.round(field.u * 0.4))
            color: "black"
        }
    }

    // ------------------------------------------------------------ message line

    Item {
        visible: field.mode === "play"
        y: field.fieldBottom
        width: parent.width
        height: field.msgH
        Rectangle {
            width: parent.width
            height: Math.max(3, Math.round(field.u * 0.4))
            color: "black"
        }
        Text {
            anchors.fill: parent
            anchors.leftMargin: Math.round(field.u * 1.5)
            anchors.rightMargin: Math.round(field.u * 1.5)
            anchors.topMargin: Math.round(field.u * 0.6)
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            maximumLineCount: field.landscape ? 2 : 3
            elide: Text.ElideRight
            font.pixelSize: field.fs
            font.bold: true
            font.family: "monospace"
            text: {
                if (field.paused) return "Paused. Tap RESUME when you’re ready."
                if (field.motion) return field.deliveryActive
                    ? (field.userBats ? "Watch the ball. Swing as it reaches the plate." : "Pitch on its way…")
                    : field.motion.label
                if (!field.st || field.rev < 0) return ""
                var s = field.st
                if (s.phase !== "play")
                    return (field.last ? field.last.text + " " : "") + s.summary
                var next = field.userBats ? B.batterHint(s) : B.pitcherHint(s)
                if (!field.last)
                    return field.userBats ? "Pitch coming. Watch the ball and time your swing." : "You’re on the mound. " + next
                return field.last.text + "\n" + (field.userBats ? "Next pitch coming…" : next)
            }
        }
    }

    // ------------------------------------------------------------ title

    Item {
        anchors.fill: parent
        visible: field.mode === "title"

        Column {
            anchors.centerIn: parent
            spacing: Math.round(field.u * 2)

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(field.u * 4)
                PixelSprite {
                    anchors.verticalCenter: parent.verticalCenter
                    rows: Art.BATTER_SWING
                    px: field.u * 0.45
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(field.u * 0.5)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "POCKET"
                        font.pixelSize: Math.round(field.u * 8)
                        font.bold: true
            font.family: "monospace"
                        font.letterSpacing: field.u * 1.2
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "DIAMOND"
                        font.pixelSize: Math.round(field.u * 8)
                        font.bold: true
            font.family: "monospace"
                        font.letterSpacing: field.u * 1.2
                    }
                }
                PixelSprite {
                    anchors.verticalCenter: parent.verticalCenter
                    rows: Art.PITCHER_THROW
                    px: field.u * 0.4
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.round(field.width * 0.6)
                height: Math.max(3, Math.round(field.u * 0.4))
                color: "black"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "HANDHELD BASEBALL"
                font.pixelSize: Math.round(field.fs * 1.1)
                font.bold: true
            font.family: "monospace"
                font.letterSpacing: field.u * 0.8
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: field.width * 0.8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Watch the pitch. Time your swing. Let balls go by. Choose a pitch and a spot when you take the mound."
                font.pixelSize: field.fs
                font.bold: true
            font.family: "monospace"
            }
        }
    }

    // ------------------------------------------------------------ final

    Item {
        anchors.fill: parent
        anchors.topMargin: field.boardH
        visible: field.mode === "final"

        readonly property int result: field.rev >= 0 && field.st ? B.userResult(field.st) : 0

        Column {
            anchors.centerIn: parent
            spacing: Math.round(field.u * 2.4)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "FINAL"
                font.pixelSize: Math.round(field.fs * 1.1)
                font.bold: true
            font.family: "monospace"
                font.letterSpacing: field.u * 0.8
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.parent.result > 0 ? "YOU WIN!" : parent.parent.result < 0 ? "CPU WINS" : "TIE GAME"
                font.pixelSize: Math.round(field.u * 9)
                font.bold: true
            font.family: "monospace"
                font.letterSpacing: field.u * 0.8
            }

            // Line score: a column per inning, then runs and hits.
            Grid {
                id: line
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property int innings: field.rev >= 0 && field.st ? field.st.inning : 1
                readonly property real cellW: Math.round(Math.min(field.u * 7, field.width * 0.6 / (innings + 3)))
                readonly property real cellH: Math.round(field.fs * 1.7)
                columns: innings + 3
                Repeater {
                    model: (line.innings + 3) * 3
                    Rectangle {
                        readonly property int r: Math.floor(index / (line.innings + 3))
                        readonly property int c: index % (line.innings + 3)
                        width: c === 0 ? line.cellW * 2 : line.cellW
                        height: line.cellH
                        color: "white"
                        border.color: "black"
                        border.width: Math.max(2, Math.round(field.u * 0.25))
                        Text {
                            anchors.centerIn: parent
                            font.pixelSize: Math.round(field.fs * (parent.r === 0 ? 0.8 : 1.05))
                            font.bold: true
            font.family: "monospace"
                            text: {
                                var s = field.st, r = parent.r, c = parent.c, n = line.innings
                                if (!s || field.rev < 0) return ""
                                if (r === 0) return c === 0 ? "" : c <= n ? String(c) : c === n + 1 ? "R" : "H"
                                var t = r - 1
                                if (c === 0) return field.teamName(t)
                                if (c <= n) return c - 1 < s.line[t].length ? String(s.line[t][c - 1]) : "X"
                                return String(c === n + 1 ? s.score[t] : s.hits[t])
                            }
                        }
                    }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: field.width * 0.8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: field.rev >= 0 && field.st ? field.st.summary : ""
                font.pixelSize: field.fs
                font.bold: true
            font.family: "monospace"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: field.st ? "Game #" + field.st.seed : ""
                font.pixelSize: Math.round(field.fs * 0.6)
                font.bold: true
            font.family: "monospace"
            }
        }
    }
}
