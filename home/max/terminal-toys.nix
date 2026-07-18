{ pkgs, ... }:
let
  palette = import ../../config/stylix/palette.nix;
in
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

  xdg.configFile = {
    # cava — Gruvbox Material Dark gradient
    "cava/config".text = ''
      [general]
      framerate = 60
      autosens = 1
      bars = 0
      bar_width = 3
      bar_spacing = 1
      lower_cutoff_freq = 20
      higher_cutoff_freq = 15000
      sleep_timer = 30

      [input]
      method = pipewire
      source = auto

      [output]
      method = ncurses
      channels = stereo

      [color]
      # 'default' = don't paint a background; the terminal's own (kitty,
      # background_opacity 0.95) shows through, keeping the subtle transparency
      background = 'default'
      # VU-meter gradient: green base, yellow mids, red peaks
      gradient = 1
      gradient_count = 4
      gradient_color_1 = '${palette.green}'
      gradient_color_2 = '${palette.yellow}'
      gradient_color_3 = '${palette.orange}'
      gradient_color_4 = '${palette.red}'

      [smoothing]
      # 0–100 scale (cava divides by 100; a float like 0.77 parses as ~0 and
      # disables smoothing). Higher = smoother/slower, lower = snappier/noisier.
      noise_reduction = 10
      monstercat = 1
    '';

    # spotify-player — shows up as a Spotify Connect device named "max-tui"; control
    # playback on (or hand off from) the official Spotify client. Streaming playback
    # needs Spotify Premium. If auth fails, register a Spotify app and set client_id:
    #   https://github.com/aome510/spotify-player#audio-sources
    "spotify-player/app.toml".text = ''
      theme = "gruvbox-material-dark"

      [device]
      name = "max-tui"

      [copy_command]
      command = "wl-copy"
      args = []
    '';

    # Gruvbox Material Dark palette for spotify-player
    "spotify-player/theme.toml".text = ''
      [[themes]]
      name = "gruvbox-material-dark"

      [themes.palette]
      background    = "${palette.bg0}"
      foreground    = "${palette.fg}"
      black         = "${palette.bg1}"
      red           = "${palette.red}"
      green         = "${palette.green}"
      yellow        = "${palette.yellow}"
      blue          = "${palette.blue}"
      magenta       = "${palette.purple}"
      cyan          = "${palette.aqua}"
      white         = "${palette.fg}"
      bright_black   = "${palette.bg2}"
      bright_red     = "${palette.red}"
      bright_green   = "${palette.green}"
      bright_yellow  = "${palette.yellow}"
      bright_blue    = "${palette.blue}"
      bright_magenta = "${palette.purple}"
      bright_cyan    = "${palette.aqua}"
      bright_white   = "${palette.fgBright}"

      [themes.component_style]
      block_title           = { fg = "${palette.yellow}" }
      border                = { fg = "${palette.bg2}" }
      playback_track        = { fg = "${palette.fg}", modifiers = ["Bold"] }
      playback_artists      = { fg = "${palette.fg}", modifiers = ["Bold"] }
      playback_album        = { fg = "${palette.yellow}" }
      playback_metadata     = { fg = "${palette.bg2}" }
      playback_progress_bar = { bg = "${palette.bg2}", fg = "${palette.green}" }
      current_playing       = { fg = "${palette.green}", modifiers = ["Bold"] }
      page_desc             = { fg = "${palette.aqua}", modifiers = ["Bold"] }
      table_header          = { fg = "${palette.blue}" }
      selection             = { modifiers = ["Bold", "Reversed"] }
    '';
  };
}
