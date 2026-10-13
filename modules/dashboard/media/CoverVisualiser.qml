pragma ComponentBehavior: Bound

import QtQuick
import M3Shapes
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.widgets
import qs.services

Item {
    id: root

    CoverArt {
        id: cover

        anchors.centerIn: parent
        shape.shape: MaterialShape.Cookie9Sided
        implicitWidth: Tokens.sizes.dashboard.mediaCoverArtSize
        implicitHeight: Tokens.sizes.dashboard.mediaCoverArtSize
    }
}
