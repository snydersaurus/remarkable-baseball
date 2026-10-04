import QtQuick
import QtQuick.Window
import "../ui"
import "../ui/Baseball.mjs" as B
Window {
    id: win
    width: 1696; height: 954; visible: true
    Game { id: game; anchors.fill: parent; frameMs: 80 }
    property int polls: 0
    property bool pausedOnce: false
    property int pausePoll: 0
    property int pausedFrame: -1
    Component.onCompleted: {
        game.start(0)
        // Find a deterministic second strike; first pitch will be taken.
        for(var seed=1;seed<1000;seed++) {
            var s=B.newGame({seed:seed,userTeam:0,innings:1})
            var first=B.preparePitch(s,null,null)
            B.pitchOnce(s,null,null,"take",first)
            if(B.preparePitch(s,null,null).where.inZone) {
                game.st=B.newGame({seed:seed,userTeam:0,innings:1});game.rev++;break
            }
        }
    }
    function fail(msg) { console.error("FAIL "+msg);Qt.exit(1) }
    Timer {
        interval: 20;running:true;repeat:true
        onTriggered: {
            win.polls++
            if(win.polls>1000){win.fail("live clock did not finish");return}
            if(!win.pausedOnce && game.deliveryActive && game.motionIndex===3) {
                win.pausedOnce=true;win.pausePoll=win.polls;win.pausedFrame=game.motionIndex;game.togglePause()
            }
            if(game.paused) {
                if(game.motionIndex!==win.pausedFrame){win.fail("clock moved while paused");return}
                if(win.polls-win.pausePoll>10) game.togglePause()
                return
            }
            if(game.st.pitches===1 && game.deliveryActive && game.motion && game.motion.ball && game.motion.ball.t>=0.8)
                game.swing()
            if(game.st.pitches>=2) {
                if(game.st.pitches!==2||["single","double","triple","homer","groundout","flyout"].indexOf(game.st.last.kind)<0) {
                    win.fail("timed second pitch did not connect");return
                }
                game.suspend()
                if(!game.paused){win.fail("suspend did not pause");return}
                console.log("PASS live timers: automatic take, pause/resume, timed swing, single commit, suspend")
                Qt.quit()
            }
        }
    }
}
