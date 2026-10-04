import QtQuick
import net.asivery.ApploadUtils 1.0

// AppLoad replaces this helper with the tablet's display-method area.
// Its lifetime is restricted to moving play and its bounds to the field.
DisplayMethodArea {
    anchors.fill: parent
    displayMethod: DisplayMethodArea.Animate
}
