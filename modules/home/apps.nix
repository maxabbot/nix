# modules/home/apps.nix — Terminal emulator, file manager, media, and misc apps.
{ pkgs, ... }:
{
  programs = {
    # ── Kitty terminal ─────────────────────────────────────────────────────────────
    # Colours and font are managed by Stylix; only behaviour settings live here.
    kitty = {
      enable = true;

      settings = {
        window_padding_width = 8;
        hide_window_decorations = "titlebar-only";
        background_opacity = "0.95";
        dynamic_background_opacity = true;

        tab_bar_edge = "bottom";
        tab_bar_style = "powerline";
        tab_powerline_style = "slanted";
        active_tab_foreground = "#282828";
        active_tab_background = "#d8a657";
        active_tab_font_style = "bold";
        inactive_tab_foreground = "#d4be98";
        inactive_tab_background = "#3c3836";
        inactive_tab_font_style = "normal";
        tab_bar_background = "#282828";

        scrollback_lines = 10000;
        enable_audio_bell = false;
        visual_bell_duration = "0.0";
        window_alert_on_bell = true;
        confirm_os_window_close = 0;
        copy_on_select = "clipboard";
        strip_trailing_spaces = "smart";
        select_by_word_characters = "@-./_~?&=%+#";
        repaint_delay = 10;
        input_delay = 3;
        sync_to_monitor = true;
        close_on_child_death = false;
        allow_remote_control = "yes";
        listen_on = "unix:/tmp/kitty";
      };

      keybindings = {
        "ctrl+shift+t" = "new_tab_with_cwd";
        "ctrl+shift+l" = "next_tab";
        "ctrl+shift+h" = "prev_tab";
        "ctrl+shift+f5" = "load_config_file";
        "ctrl+alt+t" = "new_window_with_cwd";
        "ctrl+shift+enter" = "new_window_with_cwd";
      };
    };

    # ── btop ───────────────────────────────────────────────────────────────────────
    # Uses the built-in gruvbox_material_dark theme — better fidelity than Stylix's
    # generated theme, so Stylix's btop target is disabled in stylix.nix.
    btop = {
      enable = true;
      settings = {
        color_theme = "gruvbox_material_dark";
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

    # ── bat ── configured in home/max/cli.nix (theme + pager) ──────────────────────

    # ── mpv ────────────────────────────────────────────────────────────────────────
    mpv = {
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
    zathura = {
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

    # ── Fuzzel launcher ───────────────────────────────────────────────────────────
    # Colours are managed by Stylix; only layout/behaviour settings live here.
    fuzzel = {
      enable = true;
      settings = {
        main = {
          dpi-aware = "auto";
          prompt = "❯ ";
          icons-enabled = true;
          icon-theme = "Papirus-Dark";
          lines = 10;
          width = 40;
          horizontal-pad = 20;
          vertical-pad = 8;
          inner-pad = 4;
          fuzzy = true;
          terminal = "kitty";
        };
        border = {
          width = 2;
          radius = 10;
        };
        dmenu = {
          exit-immediately-if-empty = true;
        };
      };
    };
  };

  xdg.configFile = {
    # ── Wlogout logout screen ───────────────────────────────────────────────────
    "wlogout/layout".source = ../../config/wlogout/layout;
    # Icons live in the Nix store, not /usr/share — generate CSS with correct path.
    "wlogout/style.css".text =
      builtins.replaceStrings [ "/usr/share/wlogout/icons" ] [ "${pkgs.wlogout}/share/wlogout/icons" ]
        (builtins.readFile ../../config/wlogout/style.css);
    # ── Fastfetch system info ───────────────────────────────────────────────────
    "fastfetch/config.jsonc".source = ../../config/fastfetch/config.jsonc;
    # ── Hyprlock lockscreen config ──────────────────────────────────────────────
    "hypr/hyprlock.conf".source = ../../config/hypr/hyprlock.conf;
    # ── Mise version manager ────────────────────────────────────────────────────
    "mise/config.toml".source = ../../config/mise/config.toml;
  };

  # ── Misc packages ─────────────────────────────────────────────────────────────
  home.packages = [
    pkgs.freetube
    pkgs.mise
    (pkgs.writeShellScriptBin "tmux-sessionizer" (
      builtins.readFile ../../config/scripts/tmux-sessionizer
    ))
  ];

}
