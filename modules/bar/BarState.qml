import QtQuick
QtObject {
    property string activePopup: ""
    property bool audioOpen: activePopup === "audio"
    property bool appsOpen: activePopup === "apps"
    property bool powerOpen: activePopup === "power"
    property bool menuOpen: activePopup === "menu"
    property bool networkOpen: activePopup === "network"
    function open(name: string): void { activePopup = name; }
    // The popup a click outside just closed: its own button must not reopen it at once.
    property string dismissed: ""
    property real dismissedAt: 0
    function dismiss(name: string): void {
        dismissed = name;
        dismissedAt = Date.now();
        if (activePopup === name) activePopup = "";
    }
    function toggle(name: string): void {
        if (activePopup !== name && dismissed === name && Date.now() - dismissedAt < 300) return;
        activePopup = activePopup === name ? "" : name;
    }
    function close(): void { activePopup = ""; }
}
