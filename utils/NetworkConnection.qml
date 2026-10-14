pragma Singleton

import QtQuick
import Caelestia
import Caelestia.I18n
import qs.services

/**
 * NetworkConnection
 *
 * Centralized utility for network connection logic. Provides a single source of truth
 * for connecting to wireless networks, eliminating code duplication across
 * controlcenter components and bar popouts.
 *
 * Usage:
 * ```qml
 * import qs.utils
 *
 * // With Session object (controlcenter)
 * NetworkConnection.handleConnect(network, session);
 *
 * // Without Session object (bar popouts) - provide password dialog callback
 * NetworkConnection.handleConnect(network, null, (network) => {
 *     // Show password dialog
 *     root.passwordNetwork = network;
 *     root.showPasswordDialog = true;
 * });
 * ```
 */
QtObject {
    id: root

    /**
     * Handle network connection with automatic disconnection if needed.
     * If there's an active network different from the target, disconnects first,
     * then connects to the target network.
     *
     * @param network The network object to connect to (must have ssid property)
     * @param session Optional Session object (for controlcenter - must have network property with showPasswordDialog and pendingNetwork)
     * @param onPasswordNeeded Optional callback function(network) called when password is needed (for bar popouts)
     * @param onFailed Optional callback function(network, result) called when the connection fails for any other reason
     */
    function handleConnect(network, session, onPasswordNeeded, onFailed): void {
        if (!network) {
            return;
        }

        // Fork: a secured network without a saved profile always needs its password, so ask straight away. Upstream
        // first disconnected the current network, then tried without a password (nmcli takes ~6 s to give up) and
        // left a half-made profile behind. The password prompt connects by itself, no disconnect needed.
        if (network.isSecure && !Nmcli.hasSavedProfile(network.ssid)) {
            root.askPassword(network, session, onPasswordNeeded);
            return;
        }

        if (Nmcli.active && Nmcli.active.ssid !== network.ssid) {
            Nmcli.disconnectFromNetwork();
            Qt.callLater(() => {
                root.connectToNetwork(network, session, onPasswordNeeded, onFailed);
            });
        } else {
            root.connectToNetwork(network, session, onPasswordNeeded, onFailed);
        }
    }

    // Show the password prompt for a network (session for the old control centre, otherwise the callback)
    function askPassword(network, session, onPasswordNeeded): void {
        // Clear pending connection if exists
        if (Nmcli.pendingConnection)
            Nmcli.clearPendingConnection();

        if (session && session.network) {
            session.network.showPasswordDialog = true;
            session.network.pendingNetwork = network;
        } else if (onPasswordNeeded) {
            onPasswordNeeded(network);
        }
    }

    /**
     * Connect to a wireless network.
     * Handles both secured and open networks, checks for saved profiles,
     * and shows password dialog if needed.
     *
     * @param network The network object to connect to (must have ssid, isSecure, bssid properties)
     * @param session Optional Session object (for controlcenter - must have network property with showPasswordDialog and pendingNetwork)
     * @param onPasswordNeeded Optional callback function(network) called when password is needed (for bar popouts)
     * @param onFailed Optional callback function(network, result) called when the connection fails for any other reason
     */
    function connectToNetwork(network, session, onPasswordNeeded, onFailed): void {
        if (!network) {
            return;
        }

        // Fork: every attempt reports its result. Upstream passed no callback for saved profiles and open networks,
        // and ignored failures, so a failed attempt (e.g. a saved profile without its password) left the UI
        // waiting forever. A saved profile that needs a password now asks for one too.
        let handled = false;
        const onResult = result => {
            if (handled || !result || result.success)
                return;
            handled = true;

            if (result.needsPassword && network.isSecure) {
                root.askPassword(network, session, onPasswordNeeded);
                return;
            }

            const reason = (result.error ?? "").trim().replace(/^Error: /, "") || Tr.tr("Unknown error");
            Toaster.toast(Tr.tr("Couldn't connect to %1").arg(network.ssid), reason, "wifi_off", Toast.Error);
            if (onFailed)
                onFailed(network, result);
        };

        if (Nmcli.hasSavedProfile(network.ssid))
            Nmcli.connectSavedNetwork(network.ssid, network.bssid, onResult);
        else if (network.isSecure)
            Nmcli.connectToNetworkWithPasswordCheck(network.ssid, true, onResult, network.bssid);
        else
            Nmcli.connectToNetwork(network.ssid, "", network.bssid, onResult);
    }

    /**
     * Connect to a wireless network with a provided password.
     * Used by password dialogs when the user has already entered a password.
     *
     * @param network The network object to connect to (must have ssid, bssid properties)
     * @param password The password to use for connection
     * @param onResult Optional callback function(result) called with connection result
     */
    function connectWithPassword(network, password, onResult): void {
        if (!network) {
            return;
        }

        Nmcli.connectToNetwork(network.ssid, password || "", network.bssid || "", onResult || null);
    }
}
