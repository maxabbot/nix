pragma Singleton
// Theme.qml — Single source of truth for the Gruvbox Material Dark palette,
// the UI font, and shared metrics. Referenced as `Theme.<token>` from any
// component in this directory (no import needed — same-dir resolution).
//
// Colour token values are byte-for-byte the Gruvbox hexes previously inlined
// across every panel; change a colour here and it updates everywhere.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: theme

    // ── Optional palette override (Theme tab / matugen) ─────────────────────
    // The Theme tab writes ~/.cache/quickshell/palette.json (e.g. generated from
    // the wallpaper via matugen). A handful of high-impact tokens prefer it when
    // present; everything falls back to the fixed Gruvbox Material palette, so a
    // missing/empty file changes nothing. Read via a Process (no fatal errors on
    // a missing file); ThemePanel calls reloadPalette() after writing.
    property var palette: ({})
    function reloadPalette() { paletteProc.running = true }

    Process {
        id: paletteProc
        command: ["bash", "-c", "cat \"${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/palette.json\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { theme.palette = text ? JSON.parse(text) : ({}) }
                catch (e) { theme.palette = ({}) }
            }
        }
    }
    Component.onCompleted: reloadPalette()

    // ── Helpers ─────────────────────────────────────────────────────────────
    // The QsScreen for the monitor that currently has focus, so bar-dropdown
    // panels open where the user is working instead of a fixed default screen.
    // Returns null (→ Quickshell's default screen) until Hyprland reports focus.
    function focusedScreen() {
        var fm = Hyprland.focusedMonitor
        if (!fm) return null
        var ss = Quickshell.screens
        for (var i = 0; i < ss.length; i++)
            if (ss[i].name === fm.name) return ss[i]
        return null
    }

    // ── Font ────────────────────────────────────────────────────────────────
    readonly property string font: "JetBrainsMono Nerd Font"

    // ── Backgrounds (dark → light) ──────────────────────────────────────────
    readonly property color bgHard: "#1d2021"  // deepest — log/canvas/kbd wells
    readonly property color bg:     palette.bg    ?? "#282828"  // panel body
    readonly property color bgAlt:  palette.bgAlt ?? "#32302f"  // inputs, tiles, list rows
    readonly property color bgSoft: "#383432"  // hovered list row

    // ── Borders / separators / dark hovers ──────────────────────────────────
    readonly property color border:       palette.border ?? "#3c3836"
    readonly property color borderStrong: "#504945"

    // ── Foreground text (dim → bright) ──────────────────────────────────────
    readonly property color grayDim:  "#665c54"  // placeholders, counts
    readonly property color gray:     "#928374"  // secondary text, muted icons
    readonly property color fgDim:    "#bdae93"  // body text
    readonly property color fgSoft:   "#d5c4a1"  // toast body
    readonly property color fg:       palette.fg ?? "#d4be98"  // primary text & icons
    readonly property color fgBright: "#ebdbb2"  // emphasised / bold text

    // ── Accent (aqua) and accent-tinted surfaces ────────────────────────────
    readonly property color accent:        palette.accent   ?? "#7daea3"
    readonly property color accentBright:  "#89b482"  // pressed slider handle
    readonly property color accentBg:      palette.accentBg ?? "#2d4a52"  // active tile/button fill
    readonly property color accentBgHover: "#3a5a62"  // active tile hovered

    // ── Status / syntax colours ─────────────────────────────────────────────
    readonly property color green:   "#a9b665"
    readonly property color yellow:  "#d8a657"
    readonly property color red:     "#ea6962"
    readonly property color redDark: "#6b2a2a"
    readonly property color purple:  "#d3869b"
    readonly property color toastBg: "#2d3b3b"  // default-urgency toast fill

    // ── Translucent surfaces ────────────────────────────────────────────────
    readonly property color bgFloat: Qt.rgba(40 / 255, 40 / 255, 40 / 255, 0.80)  // overlay badge

    // ── Metrics ─────────────────────────────────────────────────────────────
    readonly property int radiusPanel:  12
    readonly property int radiusButton: 8
    readonly property int animFast:     80   // ms — hover/colour transitions
    readonly property int panelGapTop:  38   // top margin clearing Waybar (34px)
}
