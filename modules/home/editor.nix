# modules/home/editor.nix — Zed (primary) and VSCode (backup) configuration.
{ pkgs, ... }:
{
  # ── Zed ────────────────────────────────────────────────────────────────────────
  home.packages = [
    pkgs.zed-editor
    pkgs.nano
  ];
  xdg.configFile."zed/settings.json".source = ../../user/dot_config/zed/settings.json;

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
        vscodevim.vim
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
