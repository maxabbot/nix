# modules/home/editor.nix — Helix, Neovim, and Zed configuration.
# Mirrors user/dot_config/helix and user/dot_config/nvim.
{ pkgs, ... }:
{
  # ── Helix ──────────────────────────────────────────────────────────────────────
  programs.helix = {
    enable = true;
    defaultEditor = true;

    settings = {
      theme = "gruvbox";

      editor = {
        line-number = "relative";
        mouse = true;
        auto-save = true;
        completion-trigger-len = 1;
        idle-timeout = 200;
        color-modes = true;
        bufferline = "multiple";
        rulers = [ 100 ];

        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };

        file-picker.hidden = false;

        indent-guides = {
          render = true;
          character = "╎";
        };

        statusline = {
          left = [
            "mode"
            "spinner"
            "file-name"
            "file-modification-indicator"
          ];
          center = [ ];
          right = [
            "diagnostics"
            "selections"
            "position"
            "file-encoding"
            "file-line-ending"
            "file-type"
          ];
          separator = "│";
        };

        lsp.display-inlay-hints = true;
      };

      keys.normal = {
        "C-s" = ":write";
        space = {
          f = "file_picker";
          b = "buffer_picker";
          "/" = "global_search";
          w = ":write";
          q = ":quit";
        };
      };

      keys.insert = {
        "C-s" = [
          "normal_mode"
          ":write"
        ];
      };
    };

    # Language servers installed via nixpkgs (add more as needed)
    extraPackages = with pkgs; [
      # LSPs
      nil # Nix
      nixd # Nix (alternative)
      rust-analyzer
      gopls
      pyright
      typescript-language-server
      vscode-langservers-extracted # html/css/json/eslint
      bash-language-server
      yaml-language-server
      taplo # TOML
      marksman # Markdown

      # Formatters
      nixpkgs-fmt
      rustfmt
      black
      prettierd
      shfmt
    ];
  };

  # ── Neovim ─────────────────────────────────────────────────────────────────────
  programs.neovim = {
    enable = true;
    defaultEditor = false;
    viAlias = false;
    vimAlias = false;
    withPython3 = true;
    withNodeJs = true;
    withRuby = true;

    # Lazy.nvim manages plugins; we only provide system-level deps here.
    extraPackages = with pkgs; [
      # Treesitter compiler (required by nvim-treesitter)
      gcc

      # LSPs (shared with Helix)
      nil
      rust-analyzer
      gopls
      pyright
      typescript-language-server
      bash-language-server

      # Tools used by telescope / mason
      ripgrep
      fd
    ];
  };

  # Nvim config files are managed as raw files (lazy.nvim bootstraps itself)
  xdg.configFile."nvim".source = ../../user/dot_config/nvim;

  # ── Zed ────────────────────────────────────────────────────────────────────────
  # Zed is installed system-wide via development.nix (pkgs.zed-editor).
  # Config managed as a raw file from the existing source.
  xdg.configFile."zed/settings.json".source = ../../user/dot_config/zed/settings.json;
}
