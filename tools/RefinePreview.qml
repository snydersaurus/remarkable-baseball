import QtQuick
import QtQuick.Window
import "../ui"
import "../ui/Baseball.mjs" as B
Window {
 id: win
 readonly property var args: Qt.application.arguments
 width: parseInt(args[args.length-3]); height: parseInt(args[args.length-2]); visible: true
 readonly property string output: args[args.length-1]
 Game { id: game; anchors.fill: parent; manualPlayback: true }
 Component.onCompleted: {
  game.st=B.newGame({seed:1,userTeam:0,innings:1});game.mode="play";game.rev++
  game.beginDelivery(null,null)
  while(!game.motion.ball || game.motion.ball.t<0.8)game.stepMotion()
 }
 Timer { interval: 1000; running: true; onTriggered: game.grabToImage(function(r){r.saveToFile(win.output);Qt.quit()}) }
}
