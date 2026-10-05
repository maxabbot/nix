# modules/home/apps.nix — Terminal emulator, file manager, media, and misc apps.
# GUI apps (kitty, mpv, zathura, hyprlock config, freetube) are
# gated on a compositor being configured; CLI tools (btop, fastfetch, mise,
# tmux-sessionizer) apply everywhere.
{
  lib,
  config,
  osConfig,
  pkgs,
  ...
}:
let
  gui = config.custom.hm.compositor != "none";
  palette = import ../../config/stylix/palette.nix;
  renderTheme = import ../../config/stylix/palette-subst.nix { inherit lib; };
in
{
  programs = {
    # ── Kitty terminal ─────────────────────────────────────────────────────────────
    # Colours and font are managed by Stylix; only behaviour settings live here.
    kitty = lib.mkIf gui {
      enable = true;

      settings = {
        window_padding_width = 8;
        hide_window_decorations = "titlebar-only";
        background_opacity = "0.75";
        dynamic_background_opacity = true;

        tab_bar_edge = "bottom";
        tab_bar_style = "powerline";
        tab_powerline_style = "slanted";
        active_tab_foreground = palette.bg0;
        active_tab_background = palette.yellow;
        active_tab_font_style = "bold";
        inactive_tab_foreground = palette.fg;
        inactive_tab_background = palette.bg1;
        inactive_tab_font_style = "normal";
        tab_bar_background = palette.bg0;

        scrollback_lines = 10000;
        enable_audio_bell = false;
        visual_bell_duration = "0.0";
        window_alert_on_bell = true;
        confirm_os_window_close = 0;
        # Under a tiling WM the compositor owns size. Remembering it also restores
        # a stale "maximized" state from ~/.cache/kitty/main.json, which made every
        # new kitty open maximized and hide the rest of its workspace.
        remember_window_size = false;
        copy_on_select = "clipboard";
        strip_trailing_spaces = "smart";
        select_by_word_characters = "@-./_~?&=%+#";
        repaint_delay = 10;
        input_delay = 3;
        sync_to_monitor = true;
        close_on_child_death = false;
        allow_remote_control = "yes";
        # Per-instance socket — a shared /tmp/kitty path clashes between instances.
        # kitty expands env vars and substitutes {kitty_pid} itself.
        listen_on = "unix:\${XDG_RUNTIME_DIR}/kitty-{kitty_pid}.sock";
      };

      keybindings = {
        # copy_and_clear_or_interrupt copies when there is a selection (and drops
        # it, so a stale highlight can't swallow a second Ctrl+C) and sends SIGINT
        # otherwise.
        #
        # Ctrl+V is not here on purpose — it needs a conditional map, see
        # extraConfig below.
        "ctrl+c" = "copy_and_clear_or_interrupt";

        "ctrl+shift+t" = "new_tab_with_cwd";
        "ctrl+shift+l" = "next_tab";
        "ctrl+shift+h" = "prev_tab";
        "ctrl+shift+f5" = "load_config_file";
        "ctrl+alt+t" = "new_window_with_cwd";
        "ctrl+shift+enter" = "new_window_with_cwd";
      };

      # Ctrl+V has to mean two different things depending on what is running, and
      # `keybindings` above is an attrset so it cannot hold one trigger twice.
      # kitty resolves a trigger to the LAST applicable definition, and a
      # --when-focus-on entry is only applicable while the focused window matches,
      # so the plain map is the fallback and the conditional one wins when the
      # `in_claude` user var is set (the `claude` wrapper in shell.nix sets it for
      # the duration of the run). `no_op` compiles to an empty definition, which
      # kitty reports as unconsumed, so the key reaches the program instead.
      # Order matters: the conditional map must come second.
      extraConfig = ''
        map ctrl+v paste_from_clipboard
        map --when-focus-on=var:in_claude ctrl+v no_op
      '';
    };

    # ── btop ───────────────────────────────────────────────────────────────────────
    # Uses the built-in gruvbox_material_dark theme — better fidelity than Stylix's
    # generated theme, so Stylix's btop target is disabled in stylix.nix.
    btop = {
      enable = true;
      settings = {
        color_theme = "gruvbox_material_dark";
        # Leave the background unpainted so kitty's translucent one shows through.
        theme_background = false;
        vim_keys = true;
        rounded_corners = true;
        graph_symbol = "braille";
        update_ms = 2000;
        proc_sorting = "cpu lazy";
        proc_tree = false;
        cpu_invert_lower = true;
        cpu_single_graph = false;
        mem_graphs = true;
        show_swap = true;
        swap_disk = true;
        show_disks = true;
        net_download = 100;
        net_upload = 100;
        net_auto = true;
      };
    };

    # ── MangoHud ───────────────────────────────────────────────────────────────────
    # Only where gaming.nix is imported (it enables Steam). The layout is the one
    # Goverlay had written to MangoHud.conf; colours, font and background come
    # from Stylix's mangohud target, so Goverlay's own colour choices are gone.
    # Goverlay can no longer save here — the file is a store symlink now.
    mangohud = lib.mkIf (gui && osConfig.programs.steam.enable) {
      enable = true;
      settings = {
        legacy_layout = 0;
        round_corners = 8;
        position = "top-left";
        table_columns = 3;
        # Stylix sizes from fonts.sizes.applications × 1.333; 18 × 1.333 keeps
        # the 24 px Goverlay had.
        font_size = lib.mkForce 18;
        font_size_text = lib.mkForce 18;
        gpu_text = "GPU";
        gpu_stats = true;
        gpu_core_clock = true;
        gpu_mem_clock = true;
        gpu_temp = true;
        gpu_power = true;
        cpu_text = "CPU";
        cpu_stats = true;
        cpu_mhz = true;
        cpu_temp = true;
        cpu_power = true;
        vram = true;
        ram = true;
        battery = true;
        fps = true;
        frame_timing = true;
        fps_limit_method = "late";
        fps_limit = 0;
        log_duration = 30;
        autostart_log = 0;
        log_interval = 100;
      };
    };

    # ── bat ── configured in home/max/cli.nix (theme + pager) ──────────────────────

    # ── mpv ────────────────────────────────────────────────────────────────────────
    mpv = lib.mkIf gui {
      enable = true;
      config = {
        profile = "gpu-hq";
        vo = "gpu";
        video-sync = "display-resample";
        interpolation = true;
        tscale = "oversample";
        hwdec = "auto-safe";
        gpu-context = "wayland";
        force-window = true;
        osc = true;
        osd-font = "JetBrainsMono Nerd Font";
        osd-font-size = 32;
        sub-font = "JetBrainsMono Nerd Font";
        sub-font-size = 40;
        sub-auto = "fuzzy";
        slang = "en,eng";
        screenshot-format = "png";
        screenshot-directory = "~/Pictures/Screenshots/mpv";
      };
      bindings = {
        "l" = "seek 5";
        "h" = "seek -5";
        "j" = "seek -60";
        "k" = "seek 60";
        ">" = "multiply speed 1.2";
        "<" = "multiply speed 0.8";
        "r" = "set speed 1.0";
        "m" = "no-osd cycle mute";
        "f" = "cycle fullscreen";
        "q" = "quit-watch-later";
        "Q" = "quit";
      };
    };

    # ── Zathura PDF viewer ─────────────────────────────────────────────────────────
    # Colours are managed by Stylix; only behaviour settings live here.
    zathura = lib.mkIf gui {
      enable = true;
      options = {
        recolor = true;
        sandbox = "none";
        statusbar-home-tilde = true;
        zoom-min = 10;
        guioptions = "";
        adjust-open = "best-fit";
      };
      mappings = {
        "j" = "scroll down";
        "k" = "scroll up";
        "h" = "scroll left";
        "l" = "scroll right";
        "d" = "navigate next";
        "u" = "navigate previous";
        "r" = "reload";
        "R" = "rotate";
        "i" = "recolor";
      };
    };
  };

  xdg.configFile = {
    # ── Fastfetch system info ───────────────────────────────────────────────────
    "fastfetch/config.jsonc".source = ../../config/fastfetch/config.jsonc;
    # ── Hyprlock lockscreen config (palette placeholders rendered at build) ──────
    "hypr/hyprlock.conf" = lib.mkIf gui { text = renderTheme ../../config/hypr/hyprlock.conf; };
    # ── Mise version manager ────────────────────────────────────────────────────
    "mise/config.toml".source = ../../config/mise/config.toml;
    # ── Thunar "Open Terminal Here" ─────────────────────────────────────────────
    # Thunar runs `exo-open --launch TerminalEmulator`. Without xfce4-settings'
    # xfce4-mime-helper, libexo reads this key as a desktop-file id and
    # otherwise falls back to xfce4-terminal.desktop, which isn't installed.
    "xfce4/helpers.rc" = lib.mkIf gui { text = "TerminalEmulator=kitty\n"; };
  };

  # ── Misc packages ─────────────────────────────────────────────────────────────
  home.packages = [
    pkgs.mise
    (pkgs.writeShellScriptBin "tmux-sessionizer" (
      builtins.readFile ../../config/scripts/tmux-sessionizer
    ))
  ]
  ++ lib.optionals gui [ pkgs.freetube ];

}
