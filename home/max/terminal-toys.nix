{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # ── Ambient ──────────────────────────────────────────────────────────────────
    cava # audio visualiser — reacts to whatever's playing (great on a spare monitor)
    chafa # render images/video as terminal graphics (sixel/kitty/symbols)

    # ── Music TUIs ───────────────────────────────────────────────────────────────
    spotify-player # full-featured Spotify TUI client
    ncspot # lightweight ncurses Spotify client

    # ── Weather ──────────────────────────────────────────────────────────────────
    wego # terminal weather (forecast graphs); `wttr` alias hits wttr.in, no config

    # ── Toys / games ─────────────────────────────────────────────────────────────
    _2048-in-terminal
    nudoku # sudoku
    vitetris # tetris

    # ── Data TUI ─────────────────────────────────────────────────────────────────
    harlequin # SQL IDE in the terminal (DuckDB/SQLite/Postgres/…)
  ];

  # cava — Gruvbox Material Dark gradient
  xdg.configFile."cava/config".text = ''
    [general]
    framerate = 60
    autosens = 1
    bars = 0

    [output]
    method = ncurses
    channels = stereo

    [color]
    background = '#282828'
    gradient = 1
    gradient_count = 6
    gradient_color_1 = '#ea6962'
    gradient_color_2 = '#e78a4e'
    gradient_color_3 = '#d8a657'
    gradient_color_4 = '#a9b665'
    gradient_color_5 = '#89b482'
    gradient_color_6 = '#7daea3'

    [smoothing]
    noise_reduction = 0.77
  '';

  # spotify-player — shows up as a Spotify Connect device named "max-tui"; control
  # playback on (or hand off from) the official Spotify client. Streaming playback
  # needs Spotify Premium. If auth fails, register a Spotify app and set client_id:
  #   https://github.com/aome510/spotify-player#audio-sources
  xdg.configFile."spotify-player/app.toml".text = ''
    theme = "gruvbox-material-dark"

    [device]
    name = "max-tui"

    [copy_command]
    command = "wl-copy"
    args = []
  '';

  # Gruvbox Material Dark palette for spotify-player
  xdg.configFile."spotify-player/theme.toml".text = ''
    [[themes]]
    name = "gruvbox-material-dark"

    [themes.palette]
    background    = "#282828"
    foreground    = "#d4be98"
    black         = "#3c3836"
    red           = "#ea6962"
    green         = "#a9b665"
    yellow        = "#d8a657"
    blue          = "#7daea3"
    magenta       = "#d3869b"
    cyan          = "#89b482"
    white         = "#d4be98"
    bright_black   = "#504945"
    bright_red     = "#ea6962"
    bright_green   = "#a9b665"
    bright_yellow  = "#d8a657"
    bright_blue    = "#7daea3"
    bright_magenta = "#d3869b"
    bright_cyan    = "#89b482"
    bright_white   = "#ddc7a1"

    [themes.component_style]
    block_title           = { fg = "#d8a657" }
    border                = { fg = "#504945" }
    playback_track        = { fg = "#d4be98", modifiers = ["Bold"] }
    playback_artists      = { fg = "#d4be98", modifiers = ["Bold"] }
    playback_album        = { fg = "#d8a657" }
    playback_metadata     = { fg = "#504945" }
    playback_progress_bar = { bg = "#504945", fg = "#a9b665" }
    current_playing       = { fg = "#a9b665", modifiers = ["Bold"] }
    page_desc             = { fg = "#89b482", modifiers = ["Bold"] }
    table_header          = { fg = "#7daea3" }
    selection             = { modifiers = ["Bold", "Reversed"] }
  '';
}
