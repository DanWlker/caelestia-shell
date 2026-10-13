pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.launcher.items
import qs.modules.launcher.services

StyledListView {
    id: root

    required property SearchBar search
    required property ScreenState screenState

    property string displayText

    readonly property string requestedState: stateForText(search.text)
    readonly property string displayState: stateForText(displayText)

    function syncDisplayText(): void {
        if (screenState.launcher && requestedState === displayState)
            displayText = search.text;
    }

    property string highlightedScheme // "name flavour" of the highlighted >scheme row
    property string lastResultsText

    // Fork: preview the highlighted scheme while browsing >scheme; the applied one comes back on leaving
    function updateSchemePreview(): void {
        const scheme = (currentItem as SchemeItem)?.modelData;
        if (screenState.launcher && state === "scheme" && scheme?.colours) {
            highlightedScheme = `${scheme.name} ${scheme.flavour}`;
            Schemes.preview(scheme);
        } else {
            Schemes.stopPreview();
        }
    }

    // Fork: in >scheme, a new search starts at the top, no search starts on the applied scheme (so the preview
    // starts unchanged), and a reload of the list (scheme files changed) keeps the highlighted scheme
    function indexForResults(values: var): int {
        const sameSearch = displayText === lastResultsText;
        lastResultsText = displayText;
        if (displayState !== "scheme")
            return 0;
        const key = sameSearch ? highlightedScheme : Schemes.transformSearch(displayText).trim() ? "" : Schemes.currentScheme;
        return key ? Math.max(0, values.findIndex(s => `${s.name} ${s.flavour}` === key)) : 0;
    }

    function stateForText(text: string): string {
        const prefix = GlobalConfig.launcher.actionPrefix;
        if (text.startsWith(prefix)) {
            if (text.startsWith(`${prefix}scheme `))
                return "scheme";

            return "actions";
        }

        return "apps";
    }

    function resultsForText(text: string): var {
        switch (stateForText(text)) {
        case "actions":
            return Actions.query(text);
        case "scheme":
            return Schemes.query(text);
        default:
            return Apps.search(text);
        }
    }

    model: ScriptModel {
        values: root.resultsForText(root.displayText)
        onValuesChanged: root.currentIndex = root.indexForResults(values)
    }

    spacing: Tokens.spacing.small
    orientation: Qt.Vertical
    implicitHeight: (Tokens.sizes.launcher.itemHeight + spacing) * Math.min(Config.launcher.maxShown, count) - spacing

    preferredHighlightBegin: 0
    preferredHighlightEnd: height
    highlightRangeMode: ListView.ApplyRange

    highlightFollowsCurrentItem: false
    highlight: StyledRect {
        radius: Tokens.rounding.large
        color: Colours.palette.m3onSurface
        opacity: 0.08

        y: root.currentItem?.y ?? 0
        implicitWidth: root.width
        implicitHeight: root.currentItem?.implicitHeight ?? 0

        Behavior on y {
            Anim {}
        }
    }

    state: screenState.launcher ? requestedState : displayState
    onStateChanged: updateSchemePreview()
    onCurrentItemChanged: updateSchemePreview()

    Component.onCompleted: displayText = search.text
    Component.onDestruction: Schemes.stopPreview()

    states: [
        State {
            name: "apps"

            PropertyChanges {
                root.delegate: appItem
            }
        },
        State {
            name: "actions"

            PropertyChanges {
                root.delegate: actionItem
            }
        },
        State {
            name: "scheme"

            PropertyChanges {
                root.delegate: schemeItem
            }
        }
    ]

    transitions: Transition {
        SequentialAnimation {
            ParallelAnimation {
                Anim {
                    target: root
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardAccel
                }
                Anim {
                    target: root
                    property: "scale"
                    from: 1
                    to: 0.9
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardAccel
                }
            }
            PropertyAction {
                target: root
                property: "delegate"
                value: null
            }
            ScriptAction {
                script: root.displayText = root.search.text
            }
            PropertyAction {
                target: root
                property: "delegate"
            }
            ParallelAnimation {
                Anim {
                    target: root
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardDecel
                }
                Anim {
                    target: root
                    property: "scale"
                    from: 0.9
                    to: 1
                    duration: Tokens.anim.durations.small
                    easing: Tokens.anim.standardDecel
                }
            }
            PropertyAction {
                targets: [root.add, root.remove]
                property: "enabled"
                value: true
            }
        }
    }

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }

    add: Transition {
        enabled: !root.state

        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            from: 0
            to: 1
        }
    }

    remove: Transition {
        enabled: !root.state

        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            from: 1
            to: 0
        }
    }

    move: Transition {
        Anim {
            property: "y"
        }
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            to: 1
        }
    }

    addDisplaced: Transition {
        Anim {
            property: "y"
            type: Anim.StandardSmall
        }
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            to: 1
        }
    }

    displaced: Transition {
        Anim {
            property: "y"
        }
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            to: 1
        }
    }

    Component {
        id: appItem

        AppItem {
            screenState: root.screenState
        }
    }

    Component {
        id: actionItem

        ActionItem {
            list: root
        }
    }

    Component {
        id: schemeItem

        SchemeItem {
            list: root
        }
    }

    Connections {
        function onTextChanged() {
            root.syncDisplayText();
        }

        target: root.search
    }

    // The highlighted scheme's file changed: show the new colours
    Connections {
        function onDataChanged(): void {
            root.updateSchemePreview();
        }

        target: (root.currentItem as SchemeItem)?.modelData ?? null
        ignoreUnknownSignals: true
    }

    Connections {
        function onLauncherChanged() {
            root.syncDisplayText();
            root.updateSchemePreview();
        }

        target: root.screenState
    }
}
