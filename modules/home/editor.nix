# modules/home/editor.nix — Zed (primary) and VSCode (backup) configuration.
{ pkgs, ... }:
{
  # ── Zed ────────────────────────────────────────────────────────────────────────
  home.packages = [
    pkgs.zed-editor
    pkgs.nano
  ];

  xdg.configFile."zed/settings.json" = {
    force = true;
    text = builtins.toJSON {

    # ── Extensions (auto-installed) ─────────────────────────────────────────────
    auto_install_extensions = {
      "gruvbox-material" = true;
      "colored-zed-icons" = true;
      "dockerfile" = true;
      "github-actions" = true;
      "ruff" = true;
      "toml" = true;
      "html" = true;
      "nix" = true;
    };

    # ── Appearance ──────────────────────────────────────────────────────────────
    theme = {
      mode = "system";
      light = "Gruvbox Material Light";
      dark = "Gruvbox Material Dark";
    };
    icon_theme = {
      mode = "system";
      light = "Zed (Default)";
      dark = "Colored Zed Icons Theme Dark";
    };
    ui_font_family = "JetBrainsMono Nerd Font";
    ui_font_size = 16;
    buffer_font_family = "JetBrainsMono Nerd Font";
    buffer_font_size = 15;

    # ── Editor ──────────────────────────────────────────────────────────────────
    base_keymap = "VSCode";
    cli_default_open_behavior = "existing_window";
    soft_wrap = "editor_width";
    tab_size = 2;
    hard_tabs = false;
    autosave = "on_focus_change";
    format_on_save = "on";
    cursor_blink = false;
    current_line_highlight = "all";
    diff_view_style = "unified";
    line_ending = "enforce_lf";
    scrollbar = { show = "never"; };
    relative_line_numbers = true;

    indent_guides = {
      enabled = true;
      coloring = "indent_aware";
    };
    inlay_hints = {
      enabled = true;
      show_type_hints = true;
      show_parameter_hints = true;
      show_other_hints = true;
    };

    # ── Panels ──────────────────────────────────────────────────────────────────
    project_panel = {
      entry_spacing = "comfortable";
      dock = "left";
    };
    outline_panel = {
      dock = "left";
    };
    git_panel = {
      show_count_badge = true;
      tree_view = true;
      dock = "left";
    };
    collaboration_panel = {
      button = false;
    };

    # ── MCP context servers ──────────────────────────────────────────────────────
    # brave_api_key intentionally omitted — configure via Zed UI or a secrets manager
    context_servers = {
      "mcp-server-markitdown" = {
        enabled = true;
        remote = false;
        settings = {
          package_version = "latest";
        };
      };
      "mcp-server-brave-search" = {
        enabled = true;
        remote = false;
        settings = { };
      };
    };

    # ── Agent ───────────────────────────────────────────────────────────────────
    agent_servers = {
      "claude-acp" = { type = "registry"; };
    };
    agent = {
      play_sound_when_agent_done = "when_hidden";
      sidebar_side = "right";
      dock = "right";
      default_model = {
        provider = "zed.dev";
        model = "claude-sonnet-4-6";
        effort = "high";
        enable_thinking = true;
      };
      favorite_models = [ ];
      model_parameters = [ ];
    };

    # ── Git ─────────────────────────────────────────────────────────────────────
    git = {
      inline_blame = {
        show_commit_summary = true;
      };
    };

    # ── Terminal ────────────────────────────────────────────────────────────────
    terminal = {
      font_family = "JetBrainsMono Nerd Font";
      font_size = 15;
      blinking = "terminal_controlled";
      cursor_shape = "bar";
      shell = { program = "zsh"; };
      working_directory = "current_project_directory";
      env = { TERM = "xterm-256color"; };
    };

    # ── File type associations ───────────────────────────────────────────────────
    # github-actions extension auto-detects workflow files by content/path
    file_types = {
      "sql" = [ "*.sql" ];
    };

    # ── LSP ─────────────────────────────────────────────────────────────────────
    lsp = {
      "rust-analyzer" = {
        initialization_options = {
          check = { command = "clippy"; };
          cargo = { allFeatures = true; };
          inlayHints = {
            maxLength = 40;
            lifetimeElisionHints = { enable = "skip_trivial"; };
          };
          procMacro = { enable = true; };
        };
      };
      "pyright" = {
        settings = {
          "python.analysis" = {
            typeCheckingMode = "basic";
            autoSearchPaths = true;
            useLibraryCodeForTypes = true;
            diagnosticMode = "openFilesOnly";
          };
        };
      };
      "gopls" = {
        initialization_options = {
          usePlaceholders = true;
          analyses = {
            shadow = true;
            unusedwrite = true;
            useany = true;
          };
          staticcheck = true;
          hints = {
            assignVariableTypes = true;
            compositeLiteralFields = true;
            constantValues = true;
            functionTypeParameters = true;
            parameterNames = true;
            rangeVariableTypes = true;
          };
        };
      };
      "typescript-language-server" = {
        initialization_options = {
          preferences = {
            includeInlayParameterNameHints = "all";
            includeInlayPropertyDeclarationTypeHints = true;
            includeInlayVariableTypeHints = true;
          };
        };
      };
      "nil" = {
        initialization_options = {
          formatting = { command = [ "nixfmt" ]; };
        };
      };
    };

    # ── Per-language settings ────────────────────────────────────────────────────
    languages = {
      "Python" = {
        tab_size = 4;
        format_on_save = "on";
        formatter = { language_server = { name = "ruff"; }; };
        language_servers = [
          "pyright"
          "ruff"
        ];
      };
      "Go" = {
        hard_tabs = true;
        tab_size = 4;
        format_on_save = "on";
      };
      "Rust" = { format_on_save = "on"; };
      "TypeScript" = {
        format_on_save = "on";
        formatter = { language_server = { name = "typescript-language-server"; }; };
      };
      "JavaScript" = {
        format_on_save = "on";
        formatter = { language_server = { name = "typescript-language-server"; }; };
      };
      "JSON" = {
        tab_size = 2;
        format_on_save = "on";
      };
      "YAML" = {
        tab_size = 2;
        format_on_save = "off";
      };
      "TOML" = {
        tab_size = 2;
        format_on_save = "on";
      };
      "Markdown" = {
        soft_wrap = "editor_width";
        format_on_save = "off";
      };
      "Shell Script" = { format_on_save = "off"; };
      "Dockerfile" = { format_on_save = "off"; };
      "Nix" = {
        tab_size = 2;
        format_on_save = "off";
      };
    };
  };
  };

  # ── VSCode (backup editor) ─────────────────────────────────────────────────────
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;

    profiles.default = {
      userSettings = {
        "editor.fontFamily" = "'JetBrainsMono Nerd Font', 'Droid Sans Mono', monospace";
        "editor.fontSize" = 14;
        "editor.lineNumbers" = "relative";
        "editor.formatOnSave" = true;
        "editor.rulers" = [ 100 ];
        "editor.minimap.enabled" = false;
        "editor.bracketPairColorization.enabled" = true;
        "editor.inlayHints.enabled" = "on";
        "workbench.colorTheme" = "Gruvbox Material Dark";
        "workbench.iconTheme" = "material-icon-theme";
        "terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font'";
        "files.autoSave" = "onFocusChange";
        "window.titleBarStyle" = "custom";
        "telemetry.telemetryLevel" = "off";
      };

      extensions = with pkgs.vscode-extensions; [
        jdinhlife.gruvbox
        esbenp.prettier-vscode
        dbaeumer.vscode-eslint
        ms-python.python
        rust-lang.rust-analyzer
        golang.go
        jnoortheen.nix-ide
        redhat.vscode-yaml
        tamasfe.even-better-toml
        pkief.material-icon-theme
      ];
    };
  };
}
