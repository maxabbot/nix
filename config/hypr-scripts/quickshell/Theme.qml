pragma Singleton
// Theme.qml — Single source of truth for the Gruvbox Material Dark palette,
// the UI font, and shared metrics. Referenced as `Theme.<token>` from any
// component in this directory (no import needed — same-dir resolution).
//
// Base colours are @token@ placeholders rendered at build time from
// config/stylix/palette.nix (see hyprland.nix); derived tokens (accent
// surfaces, toast fills, extra fg steps) are defined here and stay literal.
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: theme

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
    readonly property color bgHard: "@bg0Hard@"  // deepest — log/canvas/kbd wells
    readonly property color bg:     "@bg0@"  // panel body
    readonly property color bgAlt:  "@bgAlt@"  // inputs, tiles, list rows
    readonly property color bgSoft: "#383432"  // hovered list row

    // ── Borders / separators / dark hovers ──────────────────────────────────
    readonly property color border:       "@bg1@"
    readonly property color borderStrong: "@bg2@"

    // ── Foreground text (dim → bright) ──────────────────────────────────────
    readonly property color grayDim:  "@bg3@"  // placeholders, counts
    readonly property color gray:     "@gray@"  // secondary text, muted icons
    readonly property color fgDim:    "#bdae93"  // body text
    readonly property color fgSoft:   "#d5c4a1"  // toast body
    readonly property color fg:       "@fg@"  // primary text & icons
    readonly property color fgBright: "#ebdbb2"  // emphasised / bold text

    // ── Accent (aqua) and accent-tinted surfaces ────────────────────────────
    readonly property color accent:        "@blue@"
    readonly property color accentBright:  "@aqua@"  // pressed slider handle
    readonly property color accentBg:      "#2d4a52"  // active tile/button fill
    readonly property color accentBgHover: "#3a5a62"  // active tile hovered

    // ── Status / syntax colours ─────────────────────────────────────────────
    readonly property color green:   "@green@"
    readonly property color yellow:  "@yellow@"
    readonly property color orange:  "@orange@"  // scratchpad identity (matches hyprland border)
    readonly property color red:     "@red@"
    readonly property color redDark: "#6b2a2a"
    readonly property color purple:  "@purple@"
    readonly property color toastBg: "#2d3b3b"  // default-urgency toast fill

    // ── Translucent surfaces ────────────────────────────────────────────────
    readonly property color bgFloat: "#cc@bg0-hex@"  // bg0 at 80% — overlay badge

    // ── Metrics ─────────────────────────────────────────────────────────────
    readonly property int radiusPanel:  12
    readonly property int radiusButton: 8
    readonly property int animFast:     80   // ms — hover/colour transitions
    readonly property int panelGapTop:  38   // top margin clearing Waybar (36px)
}
