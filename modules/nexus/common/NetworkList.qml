pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus

ItemList {
    id: root

    required property NexusState nState
    property int limit: 0 // 0 = show all
    property bool enableFilter
    property int filterKey // Fork: changing it re-applies networkFilter (AllNetworksPage binds its filter states here)
    property string filterText // Fork: only networks whose name contains this (case-insensitive)

    signal networkSelected(ap: Nmcli.AccessPoint)

    function networkFilter(ap: Nmcli.AccessPoint): bool {
        return true;
    }

    // Fork: sorted once per update (throttled) instead of as a live binding over every access point, and each
    // network's saved-profile check runs once instead of on every comparison. The binding froze the shell for
    // seconds on each scan with 100+ networks.
    function refreshNetworks(): void {
        const connecting = Nmcli.connectingSsid();
        // Lower rank sorts higher in the list
        const ranked = Nmcli.networks.map(n => ({
                    n,
                    rank: n.active ? 0 : n.ssid === connecting ? 1 : Nmcli.hasSavedProfile(n.ssid) ? 2 : 3,
                    strength: n.strength
                }));
        ranked.sort((a, b) => a.rank - b.rank || b.strength - a.strength);
        const search = root.filterText.trim().toLowerCase();
        const sorted = ranked.map(r => r.n).filter(n => !search || n.ssid.toLowerCase().includes(search));
        if (root.limit > 0 && sorted.length > root.limit)
            sorted.length = root.limit;
        networksModel.values = root.enableFilter ? sorted.filter(root.networkFilter) : sorted;
    }

    function scheduleRefresh(): void {
        if (!refreshTimer.running)
            refreshTimer.start();
    }

    onLimitChanged: scheduleRefresh()
    onEnableFilterChanged: scheduleRefresh()
    onFilterKeyChanged: scheduleRefresh()
    onFilterTextChanged: refreshNetworks() // Immediately, so typing feels direct
    Component.onCompleted: refreshNetworks()

    showList: Nmcli.wifiEnabled
    placeholderIcon: Nmcli.wifiEnabled ? "wifi_find" : "signal_wifi_off"
    placeholderText: Nmcli.wifiEnabled ? Tr.tr("No networks found") : Tr.tr("Wi-Fi disabled")
    extraHeight: Nmcli.scanning ? Tokens.rounding.extraSmall : 0 // Inline so it isn't affected by anim
    list.anchors.top: scanningIndicator.bottom

    model: ScriptModel {
        id: networksModel
    }

    Timer {
        id: refreshTimer

        interval: 100
        onTriggered: root.refreshNetworks()
    }

    Connections {
        function onNetworksUpdated(): void {
            root.scheduleRefresh();
        }

        function onNetworksChanged(): void {
            root.scheduleRefresh();
        }

        function onSavedConnectionSsidsChanged(): void {
            root.scheduleRefresh();
        }

        function onWirelessInterfacesChanged(): void {
            root.scheduleRefresh(); // Connecting state
        }

        target: Nmcli
    }

    delegate: StateLayer {
        id: network

        required property int index
        required property var modelData
        property bool currentSelected
        property real textOpacity: disabled ? 0.5 : 1

        disabled: currentSelected || Nmcli.connectingSsid() === modelData.ssid

        anchors.left: root.list.contentItem.left
        anchors.right: root.list.contentItem.right
        implicitHeight: networkLayout.implicitHeight + networkLayout.anchors.margins * 2
        radius: Tokens.rounding.extraSmall
        bottomLeftRadius: root?.last && index === root.list.count - 1 ? Tokens.rounding.extraLarge : radius
        bottomRightRadius: root?.last && index === root.list.count - 1 ? Tokens.rounding.extraLarge : radius
        anchors.fill: undefined

        onClicked: {
            if (!modelData.active) {
                // Fork: upstream had no password prompt here and waited forever. A network that needs a password
                // opens the Add network page pre-filled with it; any other failure re-enables the row.
                // Greyed while connecting; set before connecting, since the password prompt can open immediately.
                currentSelected = true;
                root.networkSelected(modelData);
                NetworkConnection.handleConnect(modelData, null, ap => {
                    network.currentSelected = false;
                    root.nState.connectSsid = ap.ssid;
                    root.nState.openSubPage(2); // Add network sub-page
                }, () => network.currentSelected = false);
            } else {
                // Active network: open its detail/settings sub-page.
                root.nState.selectedNetworkSsid = modelData.ssid;
                root.nState.networkDetailsFromSaved = false;
                root.nState.openSubPage(3);
            }
        }

        Behavior on textOpacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Connections {
            function onActiveChanged(): void {
                if (network.modelData.active)
                    network.currentSelected = false;
            }

            target: network.modelData
        }

        Connections {
            function onNetworkSelected(ap: Nmcli.AccessPoint): void {
                if (ap !== network.modelData)
                    network.currentSelected = false;
            }

            target: root
        }

        RowLayout {
            id: networkLayout

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            anchors.leftMargin: Tokens.padding.extraLarge
            anchors.rightMargin: Tokens.padding.extraLarge
            spacing: Tokens.spacing.medium

            MaterialIcon {
                text: Icons.getNetworkIcon(network.modelData.strength)
                color: network.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
                opacity: network.textOpacity
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                opacity: network.textOpacity

                StyledText {
                    Layout.fillWidth: true
                    text: network.modelData.ssid
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        const net = network.modelData;
                        let status = "";
                        if (net.active)
                            status = Tr.trCtx("Connected", "network connected");
                        else if (Nmcli.hasSavedProfile(net.ssid))
                            status = Tr.trCtx("Saved", "network saved");
                        if (status)
                            // TRANSLATORS: %1 = security type, %2 = connection status
                            return Tr.trCtx("Security: %1 • %2", "network security and status").arg(net.security).arg(status);
                        return Tr.trCtx("Security: %1", "network security").arg(net.security);
                    }
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }
            }

            AnimLoader {
                sourceComp: Nmcli.connectingSsid() === network.modelData.ssid ? loadingComp : iconComp

                Component {
                    id: iconComp

                    MaterialIcon {
                        text: network.modelData.active ? "settings" : "lock"
                        color: network.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                        opacity: network.textOpacity
                    }
                }

                Component {
                    id: loadingComp

                    LoadingIndicator {
                        implicitSize: Math.round(Tokens.font.icon.medium.pointSize * 1.3)
                    }
                }
            }
        }
    }

    StyledProgressBar {
        id: scanningIndicator

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 1
        implicitHeight: Nmcli.scanning ? Tokens.rounding.extraSmall : 0
        indeterminate: true

        Behavior on implicitHeight {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }
}
