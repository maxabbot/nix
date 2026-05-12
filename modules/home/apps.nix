# modules/home/apps.nix — Terminal emulator, file manager, media, and misc apps.
{ pkgs, config, lib, ... }:
{
  # ── Kitty terminal ─────────────────────────────────────────────────────────────
  programs.kitty = {
    enable = true;

    font = {
      name = "JetBrainsMono Nerd Font";
      size = 13.0;
    };

    settings = {
      # ── Gruvbox Material Dark palette (fallback; matugen overrides at runtime) ──
      foreground = "#d4be98";
      background = "#282828";
      selection_foreground = "#282828";
      selection_background = "#d4be98";

      color0 = "#3c3836";
      color8 = "#928374";
      color1 = "#ea6962";
      color9 = "#ea6962";
      color2 = "#a9b665";
      color10 = "#a9b665";
      color3 = "#d8a657";
      color11 = "#d8a657";
      color4 = "#7daea3";
      color12 = "#7daea3";
      color5 = "#d3869b";
      color13 = "#d3869b";
      color6 = "#89b482";
      color14 = "#89b482";
      color7 = "#d4be98";
      color15 = "#d4be98";

      cursor = "#d4be98";
      cursor_text_color = "#282828";
      url_color = "#7daea3";

      # ── Window ──────────────────────────────────────────────────────────────
      window_padding_width = 8;
      hide_window_decorations = "titlebar-only";
      background_opacity = "0.95";
      dynamic_background_opacity = true;

      # ── Tab bar ──────────────────────────────────────────────────────────────
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

      # ── Misc ─────────────────────────────────────────────────────────────────
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

    # Load matugen-generated colors at runtime (overrides static palette above)
    extraConfig = "include /tmp/kitty-matugen-colors.conf";

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
  programs.btop = {
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

  # ── mpv ────────────────────────────────────────────────────────────────────────
  programs.mpv = {
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
  programs.zathura = {
    enable = true;
    options = {
      # Gruvbox Material Dark colors
      default-bg = "#282828";
      default-fg = "#d4be98";
      statusbar-bg = "#3c3836";
      statusbar-fg = "#d4be98";
      inputbar-bg = "#282828";
      inputbar-fg = "#d4be98";
      notification-bg = "#282828";
      notification-fg = "#d4be98";
      notification-error-bg = "#282828";
      notification-error-fg = "#ea6962";
      notification-warning-bg = "#282828";
      notification-warning-fg = "#d8a657";
      highlight-color = "#d8a657";
      highlight-active-color = "#a9b665";
      completion-bg = "#3c3836";
      completion-fg = "#d4be98";
      completion-highlight-bg = "#504945";
      completion-highlight-fg = "#d4be98";
      recolor-lightcolor = "#282828";
      recolor-darkcolor = "#d4be98";
      recolor = true;

      # Behaviour
      sandbox = "none";
      statusbar-home-tilde = true;
      font = "JetBrainsMono Nerd Font 12";
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
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=12";
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
      colors = {
        background = "282828f2";
        text = "d4be98ff";
        match = "7daea3ff";
        selection = "3c3836ff";
        selection-text = "d4be98ff";
        selection-match = "7daea3ff";
        border = "7daea34d";
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

  # ── Cava audio visualizer ─────────────────────────────────────────────────────
  # Wrapper merges static config_base with matugen-generated colors at launch
  xdg.configFile."cava/config_base".source = ../../config/cava/config;

  # ── SwayOSD volume/brightness overlay ─────────────────────────────────────────
  # Style is generated by matugen into ~/.config/swayosd/style.css
  services.swayosd = {
    enable = true;
    topMargin = 0.9;
    stylePath = "${config.home.homeDirectory}/.config/swayosd/style.css";
  };

  # ── Swaync notification daemon config ─────────────────────────────────────────
  xdg.configFile."swaync/config.json".source = ../../config/swaync/config.json;
  xdg.configFile."swaync/style.css".source = ../../config/swaync/style.css;

  # ── Wlogout logout screen ─────────────────────────────────────────────────────
  xdg.configFile."wlogout/layout".source = ../../config/wlogout/layout;
  xdg.configFile."wlogout/style.css".source = ../../config/wlogout/style.css;

  # ── Fastfetch system info ─────────────────────────────────────────────────────
  xdg.configFile."fastfetch/config.jsonc".source = ../../config/fastfetch/config.jsonc;

  # ── Hyprlock lockscreen config ────────────────────────────────────────────────
  xdg.configFile."hypr/hyprlock.conf".source = ../../config/hypr/hyprlock.conf;

  # ── Misc packages ─────────────────────────────────────────────────────────────
  home.packages = [
    pkgs.mise
    # cava with matugen color merging: combines config_base + colors at launch
    (lib.hiPrio (pkgs.writeShellScriptBin "cava" ''
      mkdir -p ~/.config/cava
      cat ~/.config/cava/config_base ~/.config/cava/colors > ~/.config/cava/config 2>/dev/null
      exec ${pkgs.cava}/bin/cava "$@"
    ''))
    # fzf+tmux project picker bound to <prefix>f / CTRL-f
    (pkgs.writeShellScriptBin "tmux-sessionizer" (builtins.readFile ../../config/scripts/tmux-sessionizer))
  ];

  # ── Mise version manager ──────────────────────────────────────────────────────
  xdg.configFile."mise/config.toml".source = ../../config/mise/config.toml;
}
