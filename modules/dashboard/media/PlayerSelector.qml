import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.services

// Player switcher, moved here from the removed lyrics panel (fork)
SplitButton {
    id: root

    type: SplitButton.Tonal
    disabled: !Players.list.length
    active: menuItems.find(m => m.modelData === Players.active) ?? menuItems[0] ?? null
    menu.onItemSelected: item => Players.manualActive = (item as PlayerItem).modelData

    menuItems: playerList.instances
    fallbackIcon: "music_off"
    fallbackText: Tr.trCtx("No players", "no media players active")

    minLeftWidth: Tokens.sizes.dashboard.mediaSectionWidth - expandBtn.implicitWidth - spacing
    label.Layout.maximumWidth: minLeftWidth - iconLabel.implicitWidth - textRow.spacing - textRow.anchors.horizontalCenterOffset / 2 - horizontalPadding * 2
    label.elide: Text.ElideRight

    stateLayer.disabled: true
    menuOnTop: true

    Variants {
        id: playerList

        model: Players.list

        PlayerItem {}
    }

    component PlayerItem: MenuItem {
        required property MprisPlayer modelData

        icon: modelData === Players.active ? "check" : ""
        text: Players.getIdentity(modelData)
        activeIcon: "animated_images"
    }
}
