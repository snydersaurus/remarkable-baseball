import QtQuick
import "Baseball.mjs" as B
import "Motion.mjs" as Motion

// Pocket Diamond: the handheld's bezel and screen (Field.qml), the control
// panel beside it, and what each tap does. The rules are in Baseball.mjs.
//
// Short, finite sequences of sprite poses and ball positions. The score commits
// once the sequence finishes. The timer is stopped whenever no play is active.
Item {
    id: game

    signal quit

    property var st: null
    property int rev: 0
    property string mode: "title"       // "title", "play" or "final"
    property string pitchType: "fast"   // the user's selected pitch, kept between pitches
    property int innings: 1
    property string armed: ""           // "new" or "quit" after a first tap, waiting for a second

    property bool manualPlayback: false // Deterministic preview harness only.
    property int frameMs: 300
    property bool smoothMotion: true
    readonly property var animationSurface: fieldView.animationSurface
    property var pendingState: null
    property var delivery: null
    property var motionEvent: null
    property var motionFrames: []
    property int motionIndex: -1
    property bool deliveryActive: false
    property bool swung: false
    property string swingTiming: ""
    property int swingFrame: -1
    property bool paused: false
    readonly property bool animating: motionIndex >= 0
    readonly property var motion: animating ? (motionFrames[motionIndex] || null) : null
    readonly property bool landscape: width > height
    readonly property real u: Math.min(width, height) / 100
    readonly property real fs: Math.round(u * 3.2)
    readonly property real guard: Math.round(Math.min(width, height) * 0.06)
    readonly property bool playing: mode === "play" && st !== null && rev >= 0 && st.phase === "play"
    readonly property bool userBats: st !== null && rev >= 0 && B.userBatting(st)

    function cancelMotion() {
        motionTimer.stop()
        nextPitch.stop()
        motionIndex = -1
        motionFrames = []
        pendingState = null
        delivery = null
        motionEvent = null
        deliveryActive = false
        swung = false
        swingFrame = -1
    }
    function schedulePitch() {
        if (!manualPlayback && playing && userBats && !paused && !animating && armed === "" && visible)
            nextPitch.restart()
    }
    function beginDelivery(pitch, location) {
        if (!playing || paused || animating) return
        nextPitch.stop()
        armed = ""
        swung = false
        swingTiming = ""
        swingFrame = -1
        pendingState = JSON.parse(JSON.stringify(st))
        delivery = B.preparePitch(pendingState, pitch, location)
        // With one swing control, missed-zone pitches use a clear side lane.
        // Store that same location in the event; animation and rules agree.
        if (!delivery.where.inZone && delivery.where.x >= 0 && delivery.where.x <= 3) {
            delivery.where.x = delivery.loc === "in" ? -0.6 : 3.6
            delivery.where.y = 1.5
        }
        motionEvent = { pitch: delivery.pitch, loc: delivery.loc,
            x: delivery.where.x, y: delivery.where.y, inZone: delivery.where.inZone,
            action: "take", kind: "" }
        motionFrames = Motion.deliveryFrames(st, smoothMotion)
        deliveryActive = true
        motionIndex = 0
        if (!manualPlayback) motionTimer.restart()
    }
    function swing() {
        if (!deliveryActive || !userBats || paused || swung) return
        swung = true
        swingFrame = motionIndex
        swingTiming = Motion.swingTiming(motion)
    }
    function resolveDelivery() {
        var action = userBats ? (swung ? "swing" : "take") : null
        B.pitchOnce(pendingState, null, null, action, delivery,
                    userBats && swung ? swingTiming : null)
        motionEvent = pendingState.last
        var frames = Motion.resultFrames(st, pendingState, smoothMotion)
        deliveryActive = false
        motionFrames = frames
        motionIndex = 0
        if (!manualPlayback) motionTimer.restart()
    }
    function finishMotion() {
        if (!pendingState) return
        var result = pendingState
        cancelMotion()
        st = result
        rev++
        schedulePitch()
    }
    function stepMotion() {
        if (!animating || paused) return
        if (motionIndex + 1 < motionFrames.length) motionIndex++
        else if (deliveryActive) resolveDelivery()
        else finishMotion()
    }
    function togglePause() {
        paused = !paused
        if (paused) { motionTimer.stop(); nextPitch.stop() }
        else if (animating && !manualPlayback) motionTimer.restart()
        else schedulePitch()
    }
    function suspend() {
        // Keep a pending delivery frozen on hide; never resolve an unseen take.
        if (mode === "play" && !paused) togglePause()
    }
    onVisibleChanged: { if (!visible) suspend() }
    Component.onDestruction: { motionTimer.stop(); nextPitch.stop() }
    Timer {
        id: motionTimer
        interval: Math.max(80, game.frameMs) * (game.motion ? game.motion.beat : 1)
        repeat: true
        onTriggered: game.stepMotion()
    }
    Timer {
        id: nextPitch
        interval: 1700
        onTriggered: { if (game.playing && game.userBats && !game.paused) game.beginDelivery(null, null) }
    }
    function start(userTeam) {
        cancelMotion()
        paused = false
        st = B.newGame({ seed: Date.now() % 4294967296, userTeam: userTeam, innings: innings })
        armed = ""
        mode = "play"
        rev++
        schedulePitch()
    }
    function throwPitch(loc) {
        if (!playing || userBats || animating || paused) return
        beginDelivery(pitchType, loc)
    }
    function proceed() {
        if (animating) return
        armed = ""
        if (st.phase === "switch") B.nextHalf(st)
        else if (st.phase === "final") mode = "final"
        rev++
        schedulePitch()
    }
    function confirm(what) {
        if (animating && !paused) return
        nextPitch.stop()
        if (mode !== "play" || st.phase === "final" || armed === what) {
            armed = ""
            cancelMotion()
            if (what === "quit") game.quit()
            else { mode = "title"; paused = false; rev++ }
            return
        }
        armed = what
        paused = true
    }

    Rectangle {
        anchors.fill: parent
        color: "white"
    }

    // ------------------------------------------------------------ the handheld

    readonly property real panelW: landscape ? Math.round(u * 34) : width - Math.round(4 * u)
    readonly property real panelH: landscape ? height - guard - Math.round(3 * u)
                                             : Math.round(height * 0.34)

    Rectangle {
        id: bezel
        x: Math.round(2 * game.u)
        y: Math.round(2 * game.u)
        width: game.landscape ? game.width - game.panelW - Math.round(6 * game.u) : game.width - Math.round(4 * game.u)
        height: game.landscape ? game.height - Math.round(4 * game.u)
                               : game.height - game.panelH - Math.round(6 * game.u)
        color: "black"
        radius: Math.round(game.u * 3)

        readonly property real rim: Math.round(game.u * 2.2)
        readonly property real band: Math.round(game.u * 6)

        // A thin bright line inside the rim, like a printed screen surround.
        Rectangle {
            x: bezel.rim * 0.45
            y: bezel.rim * 0.45
            width: parent.width - bezel.rim * 0.9
            height: parent.height - bezel.rim * 0.45 - bezel.band * 0.85
            color: "transparent"
            border.color: "white"
            border.width: Math.max(2, Math.round(game.u * 0.2))
            radius: Math.round(game.u * 2)
        }
        Rectangle {
            id: screen
            x: bezel.rim
            y: bezel.rim
            width: parent.width - 2 * bezel.rim
            height: parent.height - bezel.rim - bezel.band
            color: "white"
            radius: Math.round(game.u * 1.2)
            clip: true

            Field {
                id: fieldView
                anchors.fill: parent
                motion: game.motion
                motionEvent: game.motionEvent
                deliveryActive: game.deliveryActive
                swingFrame: game.swung && game.deliveryActive ? game.motionIndex - game.swingFrame : -1
                holdingContact: game.deliveryActive && game.swung && game.swingTiming === "hit" && game.delivery !== null && game.delivery.where.inZone
                paused: game.paused
                st: game.st
                rev: game.rev
                mode: game.mode
                u: game.u
            }
        }
        // The maker's mark on the bottom band.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round((bezel.band - height) / 2)
            spacing: Math.round(game.u * 1.5)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(game.u * 1.4); height: width; rotation: 45; color: "white"
            }
            Text {
                text: "POCKET DIAMOND"
                color: "white"
                font.pixelSize: Math.round(game.u * 2.8)
                font.bold: true
                font.letterSpacing: game.u * 0.9
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(game.u * 1.4); height: width; rotation: 45; color: "white"
            }
        }
    }

    // ------------------------------------------------------------ the panel

    Item {
        id: panel
        x: game.landscape ? game.width - game.panelW - Math.round(2 * game.u) : Math.round(2 * game.u)
        y: game.landscape ? game.guard + Math.round(game.u) : game.height - game.panelH - Math.round(2 * game.u)
        width: game.panelW
        height: game.panelH

        readonly property real gap: Math.round(game.u * 1.6)
        readonly property real footH: Math.round(game.u * 10)
        readonly property real headH: Math.round(game.fs * 1.6)
        // Room for the main controls between the heading and the footer.
        readonly property real bodyH: height - headH - footH - 2 * gap

        Text {
            id: heading
            width: parent.width
            height: panel.headH
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Math.round(game.fs * 1.05)
            font.bold: true
            font.letterSpacing: game.u * 0.5
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 12
            text: {
                if (game.rev < 0) return ""
                if (game.paused) return "PAUSED"
                if (game.animating && game.motion) return game.motion.label
                if (game.mode === "title") return "NEW GAME"
                if (game.mode === "final") return "FINAL"
                if (game.st.phase === "switch") return "CHANGE SIDES"
                if (game.st.phase === "final") return "GAME OVER"
                return game.userBats ? "AT THE PLATE" : "ON THE MOUND"
            }
        }

        // ---- title: choose a side and a length
        Item {
            visible: game.mode === "title"
            y: panel.headH + panel.gap
            width: parent.width
            height: panel.bodyH - panel.footH * 0.8
            readonly property real rowH: Math.round((height - 2 * panel.gap) * (game.landscape ? 0.36 : 0.36))

            Grid {
                width: parent.width
                columns: game.landscape ? 1 : 2
                spacing: panel.gap
                readonly property real cw: game.landscape ? width : (width - panel.gap) / 2
                TextButton {
                    width: parent.cw; height: parent.parent.rowH
                    label: "BAT FIRST"; sub: "You're the visitors"
                    fontSize: Math.round(game.fs * 1.5)
                    onTapped: game.start(0)
                }
                TextButton {
                    width: parent.cw; height: parent.parent.rowH
                    label: "PITCH FIRST"; sub: "You're the home team"
                    fontSize: Math.round(game.fs * 1.5)
                    onTapped: game.start(1)
                }
            }
            Row {
                anchors.bottom: parent.bottom
                width: parent.width
                spacing: panel.gap
                readonly property real cw: (width - 2 * spacing) / 3
                Text {
                    width: parent.cw
                    height: Math.round(parent.parent.rowH * 0.6)
                    verticalAlignment: Text.AlignVCenter
                    text: "INNINGS"
                    font.pixelSize: Math.round(game.fs * 0.9)
                    font.bold: true
                }
                Repeater {
                    model: [1, 3]
                    TextButton {
                        width: parent.cw; height: Math.round(parent.parent.rowH * 0.6)
                        label: String(modelData)
                        fontSize: Math.round(game.fs * 1.3)
                        selected: game.innings === modelData
                        onTapped: game.innings = modelData
                    }
                }
            }
        }

        // One live control: letting the pitch pass is a take.
        TextButton {
            visible: game.playing && game.userBats
            y: panel.headH + panel.gap + (panel.bodyH - height) / 2
            width: parent.width
            height: Math.min(panel.bodyH, width * 1.15)
            label: "SWING"
            primary: true
            sub: game.paused ? "Paused" : game.swung ? "Swing!"
                 : game.deliveryActive ? "Watch the ball"
                 : "Next pitch coming"
            selected: false
            fontSize: Math.round(game.fs * 1.8)
            onTapped: game.swing()
        }

        // ---- pitching: a pitch (stays selected), then a spot, which throws it
        Item {
            visible: game.playing && !game.userBats
            enabled: !game.animating && !game.paused
            y: panel.headH + panel.gap
            width: parent.width
            height: panel.bodyH
            readonly property real labelH: Math.round(game.fs * 1.3)
            readonly property real typeH: Math.round((height - 2 * labelH - 3 * panel.gap) * (game.landscape ? 0.24 : 0.4))

            Text {
                id: pitchLabel
                height: parent.labelH
                verticalAlignment: Text.AlignVCenter
                text: "PITCH"
                font.pixelSize: Math.round(game.fs * 0.85)
                font.bold: true
                font.letterSpacing: game.u * 0.3
            }
            Row {
                id: types
                anchors.top: pitchLabel.bottom
                width: parent.width
                spacing: panel.gap
                Repeater {
                    model: B.PITCHES
                    TextButton {
                        width: (types.width - 2 * types.spacing) / 3
                        height: types.parent.typeH
                        label: modelData.short
                        fontSize: Math.round(game.fs * 1.05)
                        selected: game.pitchType === modelData.id
                        onTapped: game.pitchType = modelData.id
                    }
                }
            }
            Text {
                id: throwLabel
                anchors.top: types.bottom
                anchors.topMargin: panel.gap
                height: parent.labelH
                verticalAlignment: Text.AlignVCenter
                text: "THROW IT"
                font.pixelSize: Math.round(game.fs * 0.85)
                font.bold: true
                font.letterSpacing: game.u * 0.3
            }
            Grid {
                anchors.top: throwLabel.bottom
                width: parent.width
                columns: game.landscape ? 1 : 3
                spacing: panel.gap
                readonly property real avail: parent.height - throwLabel.y - throwLabel.height
                readonly property real cw: game.landscape ? width : (width - 2 * spacing) / 3
                readonly property real ch: game.landscape ? (avail - 2 * spacing) / 3 : avail
                Repeater {
                    model: B.LOCATIONS
                    TextButton {
                        width: parent.cw; height: parent.ch
                        label: modelData.short
                        sub: modelData.id === "mid" ? "Easy strike, easy to hit" : "Harder to hit, may miss"
                        fontSize: Math.round(game.fs * 1.5)
                        onTapped: game.throwPitch(modelData.id)
                    }
                }
            }
        }

        // ---- between halves, and after the last out
        TextButton {
            visible: game.mode === "play" && game.st !== null && game.rev >= 0 && game.st.phase !== "play"
            y: panel.headH + panel.gap
            width: parent.width
            height: Math.round(panel.bodyH * (game.landscape ? 0.4 : 0.6))
            label: game.st === null || game.rev < 0 ? ""
                : game.st.phase === "final" ? "FINAL SCORE"
                : game.st.half === game.st.userTeam ? "TAKE THE MOUND" : "GRAB A BAT"
            sub: "Tap to continue"
            fontSize: Math.round(game.fs * 1.6)
            onTapped: game.proceed()
        }

        // ---- after the game
        TextButton {
            visible: game.mode === "final"
            y: panel.headH + panel.gap
            width: parent.width
            height: Math.round(panel.bodyH * (game.landscape ? 0.4 : 0.6))
            label: "PLAY AGAIN"
            sub: "Same side, new game"
            fontSize: Math.round(game.fs * 1.6)
            onTapped: game.start(game.st.userTeam)
        }

        Row {
            visible: game.mode === "title"
            anchors.bottom: parent.bottom
            anchors.bottomMargin: panel.footH + panel.gap
            width: parent.width
            spacing: panel.gap
            TextButton {
                width: (parent.width - panel.gap) / 2
                height: Math.round(panel.footH * 0.65)
                label: game.frameMs >= 300 ? "RELAXED" : "CLASSIC"
                fontSize: Math.round(game.fs * 0.65)
                onTapped: game.frameMs = game.frameMs >= 300 ? 220 : 300
            }
            TextButton {
                width: (parent.width - panel.gap) / 2
                height: Math.round(panel.footH * 0.65)
                label: game.smoothMotion ? "SMOOTH" : "STEPPED"
                fontSize: Math.round(game.fs * 0.65)
                onTapped: game.smoothMotion = !game.smoothMotion
            }
        }

        // ---- footer: start over and quit
        Row {
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: panel.gap
            readonly property bool both: game.mode !== "title"
            readonly property bool canPause: game.mode === "play" && game.playing
            readonly property real buttonW: canPause ? (width - 2 * panel.gap) / 3 : (width - panel.gap) / 2
            TextButton {
                visible: parent.canPause
                width: parent.buttonW; height: panel.footH
                label: game.paused ? "RESUME" : "PAUSE"
                fontSize: Math.round(game.fs * 0.85)
                onTapped: { game.armed = ""; game.togglePause() }
            }
            TextButton {
                visible: parent.both
                width: parent.buttonW
                height: panel.footH
                label: game.armed === "new" ? "SURE?" : game.mode === "final" ? "MENU" : "NEW"
                selected: game.armed === "new"
                fontSize: Math.round(game.fs * 1.05)
                onTapped: game.confirm("new")
            }
            TextButton {
                width: parent.both ? parent.buttonW : parent.width
                height: panel.footH
                label: game.armed === "quit" ? "SURE?" : "QUIT"
                selected: game.armed === "quit"
                fontSize: Math.round(game.fs * 1.05)
                onTapped: game.confirm("quit")
            }
        }
    }
}
