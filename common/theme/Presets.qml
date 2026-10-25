pragma Singleton
import QtQuick

QtObject {
    readonly property var entries: [
        { key: "system", name: "Seu sistema", subtitle: "Segue a paleta externa", accent: "#E5B94F", bg: "#18191D" },
        { key: "gold", name: "Âmbar", subtitle: "O aconchego do original", accent: "#E5B94F", bg: "#201D18" },
        { key: "lavender", name: "Lavanda", subtitle: "Calma em tons de lilás", accent: "#BCA4F5", bg: "#201D2B" },
        { key: "ocean", name: "Oceano", subtitle: "Um respiro de azul", accent: "#80C7ED", bg: "#17232D" },
        { key: "rose", name: "Rosé", subtitle: "Suave, do seu jeito", accent: "#EDA6BB", bg: "#2A1C24" },
        { key: "forest", name: "Bosque", subtitle: "Um pouco de natureza", accent: "#A6C997", bg: "#1C261E" }
    ]
    function palette(key: string): var {
        const entry = entries.find(item => item.key === key);
        if (!entry || key === "system") return {};
        return {
            accent: entry.accent, primary: entry.accent,
            accentHover: Qt.lighter(entry.accent, 1.15).toString(),
            hover: Qt.lighter(entry.accent, 1.15).toString(),
            pressed: Qt.darker(entry.accent, 1.15).toString(),
            sidebar: entry.bg, background: entry.bg, popup: entry.bg,
            surface: Qt.lighter(entry.bg, 1.35).toString(),
            surfaceHigh: Qt.lighter(entry.bg, 1.65).toString(),
            pill: Qt.darker(entry.bg, 1.12).toString(),
            itemHover: Qt.lighter(entry.bg, 1.6).toString(),
            textPrimary: "#F5F5F3", textSecondary: "#C0BEC6", textMuted: "#96929E"
        };
    }
}
