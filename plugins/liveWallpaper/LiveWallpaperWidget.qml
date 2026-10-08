import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string wallpaperDir: homeDir + "/Videos/Wallpapers"
    readonly property string thumbnailDir: homeDir + "/.cache/dms-live-wallpapers"
    readonly property string selectedPath: expandHome(pluginData.videoPath || "")
    property int thumbnailRevision: 0

    function expandHome(path) {
        const value = String(path || "");
        return value.indexOf("~/") === 0 ? homeDir + value.slice(1) : value;
    }

    function displayName(fileName) {
        const withoutExtension = String(fileName).replace(/\.[^.]+$/, "");
        return withoutExtension.replace(/[-_]+/g, " ").replace(/\b\w/g, c => c.toUpperCase());
    }

    function thumbnailUrl(fileName) {
        return "file://" + thumbnailDir + "/" + encodeURIComponent(fileName) + ".jpg?v=" + thumbnailRevision;
    }

    function selectVideo(filePath, fileName) {
        if (pluginService)
            pluginService.savePluginData(pluginId, "videoPath", "~/Videos/Wallpapers/" + fileName);
        loadProcess.command = [homeDir + "/.local/bin/dms-live-wallpaper-load", filePath];
        loadProcess.running = true;
    }

    Component.onCompleted: thumbnailProcess.running = true

    Process {
        id: thumbnailProcess
        command: [root.homeDir + "/.local/bin/dms-live-wallpaper-thumbnails", root.wallpaperDir, root.thumbnailDir]
        onExited: root.thumbnailRevision++
    }

    Process {
        id: loadProcess
    }

    FolderListModel {
        id: videoModel
        folder: "file://" + root.wallpaperDir
        nameFilters: ["*.mp4", "*.MP4", "*.webm", "*.WEBM", "*.mkv", "*.MKV", "*.mov", "*.MOV"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "movie"
                color: Theme.primary
                size: Theme.iconSize
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "WPP"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
            }
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: "movie"
            color: Theme.primary
            size: Theme.iconSize
        }
    }

    popoutWidth: 620
    popoutHeight: 520

    popoutContent: Component {
        PopoutComponent {
            id: gallery

            headerText: "Live Wallpapers"
            detailsText: videoModel.count + " videos · click one to apply"
            showCloseButton: true

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - gallery.headerHeight - gallery.detailsHeight - Theme.spacingXL

                DankGridView {
                    anchors.fill: parent
                    clip: true
                    cellWidth: 280
                    cellHeight: 170
                    model: videoModel

                    delegate: Rectangle {
                        id: card
                        required property string fileName
                        required property string filePath
                        readonly property bool selected: root.selectedPath === filePath

                        width: 268
                        height: 158
                        radius: 12
                        clip: true
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, cardArea.containsMouse ? 0.95 : 0.75)
                        border.width: selected ? 3 : 1
                        border.color: selected ? Theme.primary : Theme.withAlpha(Theme.outlineVariant, 0.55)

                        Image {
                            anchors.fill: parent
                            anchors.bottomMargin: 36
                            source: root.thumbnailUrl(card.fileName)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 38
                            color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.97)

                            StyledText {
                                anchors.left: parent.left
                                anchors.right: selectedIcon.visible ? selectedIcon.left : parent.right
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.displayName(card.fileName)
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall
                                elide: Text.ElideRight
                            }

                            DankIcon {
                                id: selectedIcon
                                visible: card.selected
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                name: "check_circle"
                                color: Theme.primary
                                size: 18
                            }
                        }

                        MouseArea {
                            id: cardArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectVideo(card.filePath, card.fileName)
                        }
                    }
                }
            }
        }
    }
}
