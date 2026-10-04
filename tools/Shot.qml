import QtQuick
import QtQuick.Window
import "../ui"
import "../ui/Baseball.mjs" as B

// Render actual production components at deterministic points in live play.
Window {
    id: win
    readonly property var args: Qt.application.arguments
    width: parseInt(args[args.length-3]); height: parseInt(args[args.length-2])
    readonly property string prefix: args[args.length-1]
    visible: true
    color: "white"
    Game { id: game; anchors.fill: parent; manualPlayback: true }
    function scene(inZone) {
        game.cancelMotion(); game.paused=false
        for(var seed=1;seed<1000;seed++) {
            var st=B.newGame({seed:seed,userTeam:0,innings:1})
            var delivery=B.preparePitch(JSON.parse(JSON.stringify(st)),null,null)
            if(delivery.where.inZone === inZone) { game.st=st;break }
        }
        game.st.bases=[true,false,true]; game.mode="play";game.rev++
        game.beginDelivery(null,null)
    }
    function until(t) { while(game.deliveryActive && (!game.motion.ball || game.motion.ball.t<t)) game.stepMotion() }
    function finish() { var n=0;while(game.animating&&n++<100)game.stepMotion(); if(n>=100)throw new Error("unbounded motion") }
    function check(ok,message) { if(!ok)throw new Error(message) }
    property int step: 0
    property var steps: [
        ["title",function(){}],
        ["bat-set",function(){scene(true)}],
        ["windup",function(){game.stepMotion()}],
        ["ball-mid",function(){until(0.4)}],
        ["ball-near",function(){until(0.8)}],
        ["bat-swing",function(){game.swing();check(game.swingTiming==="hit","window hit");game.swing();check(game.swingFrame===game.motionIndex,"duplicate swing ignored")}],
        ["contact",function(){while(game.deliveryActive)game.stepMotion();check(game.motionEvent.kind!=="whiff","timed hit");check(game.st.pitches===0,"score waits for presentation")}],
        ["ball-flight",function(){game.stepMotion();game.stepMotion();game.stepMotion()}],
        ["runners",function(){while(game.animating&&game.motion.label!=="RUNNERS ADVANCE")game.stepMotion();if(game.animating)game.stepMotion()}],
        ["result",function(){finish();check(game.st.pitches===1,"pitch committed once")}],
        ["early-swing",function(){scene(true);game.swing();finish();check(game.st.last.kind==="whiff","early swing misses")}],
        ["taken-strike",function(){scene(true);finish();check(game.st.last.kind==="called","no swing is called strike")}],
        ["late-swing",function(){scene(true);while(game.deliveryActive)game.stepMotion();game.swing();finish();check(game.st.last.kind==="called","late swing cannot change a completed delivery")}],
        ["wide-ball",function(){scene(false);until(1)}],
        ["taken-ball",function(){finish();check(game.st.last.kind==="ball","no swing at wide pitch is ball")}],
        ["chased-ball",function(){scene(false);until(0.8);game.swing();finish();check(game.st.last.kind==="whiff","chase misses")}],
        ["paused",function(){scene(true);until(0.4);game.togglePause();var index=game.motionIndex;game.stepMotion();check(game.motionIndex===index,"pause freezes")}],
        ["pitch",function(){game.cancelMotion();game.paused=false;game.st=B.newGame({seed:55,userTeam:1,innings:1});game.rev++;game.pitchType="curve";game.throwPitch("out");until(0.6)}],
        ["final",function(){game.cancelMotion();var n=0;while(game.st.phase!=="final"&&n++<1000){if(game.st.phase==="switch")B.nextHalf(game.st);else B.pitchOnce(game.st,null,null,"swing")}check(n<1000,"game ends");game.rev++;game.mode="final"}]
    ]
    Timer {
        interval: 300;running:true;repeat:true
        onTriggered: {
            if(win.step>=win.steps.length){Qt.quit();return}
            var s=win.steps[win.step++]
            try { s[1]() } catch(e) { console.error("CHECK FAILED "+s[0]+": "+e);Qt.exit(1);return }
            var name=win.prefix+"-"+s[0]+".png"
            Qt.callLater(function(){game.grabToImage(function(r){r.saveToFile(name);console.log("saved "+name)})})
        }
    }
}
