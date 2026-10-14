pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Models
import qs.utils

// Fork: replaces upstream's launcher/services/Schemes.qml, which listed the caelestia CLI's schemes. Schemes are
// JSON files shaped like the state scheme.json ({name, flavour, mode, colours}), bundled in assets/schemes and
// read from paths.schemeDir. A user scheme with the same name and flavour replaces the bundled one.
Searcher {
    id: root

    readonly property string currentScheme: `${Colours.scheme} ${Colours.flavour}`

    function transformSearch(search: string): string {
        return search.slice(`${GlobalConfig.launcher.actionPrefix}scheme `.length);
    }

    function selector(item: var): string {
        return `${item.name} ${item.flavour}`;
    }

    function setScheme(name: string, flavour: string): bool {
        const scheme = list.find(s => s.name === name && s.flavour === flavour);
        scheme?.apply();
        return !!scheme;
    }

    list: {
        const byId = new Map();
        for (const s of schemes.instances)
            if (s.colours)
                byId.set(`${s.name} ${s.flavour}`, s);
        return [...byId.values()].sort((a, b) => `${a.name} ${a.flavour}`.localeCompare(`${b.name} ${b.flavour}`));
    }
    useFuzzy: GlobalConfig.launcher.useFuzzy.schemes
    keys: ["name", "flavour"]
    weights: [0.9, 0.1]

    IpcHandler {
        function get(): string {
            return root.currentScheme;
        }

        function list(): string {
            return root.list.map(s => `${s.name} ${s.flavour}`).join("\n");
        }

        function set(name: string, flavour: string): string {
            return root.setScheme(name, flavour) ? "ok" : `No scheme "${name} ${flavour}"`;
        }

        target: "scheme"
    }

    FileSystemModel {
        id: bundled

        recursive: true
        path: Quickshell.shellPath("assets/schemes")
        filter: FileSystemModel.Files
        nameFilters: ["*.json"]
    }

    FileSystemModel {
        id: user

        recursive: true
        path: Paths.schemesdir
        filter: FileSystemModel.Files
        nameFilters: ["*.json"]
    }

    // Bundled first, so user schemes win in the map above
    Variants {
        id: schemes

        model: [...bundled.entries, ...user.entries]

        Scheme {}
    }

    component Scheme: QtObject {
        id: scheme

        required property FileSystemEntry modelData
        property var data

        // Name and flavour default to the folder and file name, e.g. schemes/nord/dark.json
        readonly property string name: data?.name ?? modelData.parentDir.slice(modelData.parentDir.lastIndexOf("/") + 1)
        readonly property string flavour: data?.flavour ?? modelData.baseName
        readonly property var colours: data?.colours ?? null

        readonly property FileView file: FileView {
            path: scheme.modelData.path
            watchChanges: true
            onFileChanged: reload()
            onLoaded: {
                try {
                    scheme.data = JSON.parse(text());
                } catch (e) {
                    console.warn(`Invalid colour scheme ${path}: ${e}`);
                    scheme.data = null;
                }
            }
        }

        function apply(): void {
            Colours.setScheme(JSON.stringify(Object.assign({}, data, {
                name,
                flavour
            }), null, 4) + "\n");
        }

        function onClicked(list: var): void {
            list.screenState.launcher = false;
            apply();
        }
    }
}
