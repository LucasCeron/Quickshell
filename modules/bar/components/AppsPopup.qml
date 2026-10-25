pragma ComponentBehavior: Bound
import "../../../common/theme" as Theme
import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../../services" as Services

PopupWindow {
    id: root

    required property Item anchorItem
    required property var windows
    signal dismissed

    implicitWidth: 320
    implicitHeight: Math.min(500, appsColumn.implicitHeight + 40)

    color: "transparent"

    grabFocus: true

    anchor {
        item: root.anchorItem

        // qmllint disable missing-type
        edges: Edges.Right
        gravity: Edges.Right
        adjustment: PopupAdjustment.SlideY
        // qmllint enable missing-type
        margins.left: 16
    }

    Rectangle {
        anchors.fill: parent

        radius: 22

        color: Theme.Colors.alpha(Theme.Colors.popup, 250 / 255)

        border {
            width: 1
            color: Theme.Colors.alpha(Theme.Colors.accent, 56 / 255)
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 16
            contentWidth: width
            contentHeight: appsColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: appsColumn
                width: parent.width
                spacing: 8

                Text {
                    text: "Mais aplicativos · " + root.windows.length

                    color: Theme.Colors.accent

                    font {
                        pixelSize: 15
                        weight: Font.DemiBold
                    }
                }

                Item {
                    width: 1
                    height: 4
                }

                Repeater {
                    model: ScriptModel {
                        values: root.windows
                    }

                    delegate: Rectangle {
                        id: appRow

                        required property var modelData

                        readonly property var desktopEntry: DesktopEntries.heuristicLookup(modelData.appId)

                        width: appsColumn.width
                        height: 52

                        radius: 14

                        color: rowMouse.containsMouse ? Theme.Colors.appHover : "transparent"

                        IconImage {
                            id: appIcon

                            anchors {
                                left: parent.left
                                leftMargin: 10
                                verticalCenter: parent.verticalCenter
                            }

                            implicitSize: 26

                            source: Quickshell.iconPath(appRow.desktopEntry && appRow.desktopEntry.icon !== "" ? appRow.desktopEntry.icon : appRow.modelData.appId, "application-x-executable")
                        }

                        Column {
                            anchors {
                                left: appIcon.right
                                right: closeButton.left
                                leftMargin: 12
                                rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }

                            spacing: 2

                            Text {
                                width: parent.width

                                text: appRow.desktopEntry ? appRow.desktopEntry.name : appRow.modelData.appId

                                color: Theme.Colors.label

                                elide: Text.ElideRight

                                font {
                                    pixelSize: 13
                                    weight: Font.Medium
                                }
                            }

                            Text {
                                width: parent.width

                                text: appRow.modelData.title

                                color: Theme.Colors.appMuted

                                elide: Text.ElideRight

                                font.pixelSize: 10
                            }
                        }

                        Rectangle {
                            id: closeButton

                            anchors {
                                right: parent.right
                                rightMargin: 8
                                verticalCenter: parent.verticalCenter
                            }

                            width: 30
                            height: 30

                            radius: 15

                            color: closeMouse.containsMouse ? Theme.Colors.scrollHandle : "transparent"

                            Text {
                                anchors.centerIn: parent

                                text: "×"

                                color: Theme.Colors.scrollArrow

                                font.pixelSize: 18
                            }

                            MouseArea {
                                id: closeMouse

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    appRow.modelData.close();
                                }
                            }
                        }

                        MouseArea {
                            id: rowMouse

                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                                right: closeButton.left
                            }

                            hoverEnabled: true

                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                const window = appRow.modelData;
                                root.dismissed();
                                Services.Compositor.activate(window);
                            }
                        }
                    }
                }
            }
        }
    }
}
