import QtQuick
import QtQuick.Window
import "../ui"
import "../ui/Baseball.mjs" as B
Window {
    id: win
    width: 1696; height: 954; visible: true
    Game { id: game; anchors.fill: parent; manualPlayback: true }
    property int frame: 0
    property bool saving: false
    property int tail: 0
    Component.onCompleted: {
        for(var seed=1;seed<1000;seed++) {
            var st=B.newGame({seed:seed,userTeam:0,innings:1});st.bases=[true,false,true]
            var copy=JSON.parse(JSON.stringify(st)),d=B.preparePitch(copy,null,null)
            var e=B.pitchOnce(copy,null,null,'swing',d,'hit')
            if(e.kind==='double'){game.st=st;break}
        }
        game.mode='play';game.rev++;game.beginDelivery(null,null)
    }
    Timer {
        interval: 80;running:true;repeat:true
        onTriggered: {
            if(win.saving)return
            if(!game.animating && win.tail++>5){Qt.quit();return}
            if(game.deliveryActive && game.motion.ball && game.motion.ball.t>=0.8)game.swing()
            win.saving=true
            var name='shots/frames/frame-'+String(win.frame++).padStart(3,'0')+'.png'
            game.grabToImage(function(r){
                r.saveToFile(name);win.saving=false
                game.stepMotion()
            })
        }
    }
}
