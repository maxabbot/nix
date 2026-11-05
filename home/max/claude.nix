{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  statusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [
      pkgs.jq
      pkgs.git
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = builtins.readFile ../../config/claude/statusline.sh;
  };

  declared = pkgs.writeText "claude-settings-declared.json" (
    builtins.toJSON {
      # Terminal ANSI colours, i.e. kitty's Gruvbox palette, over Claude Code's own RGB theme
      theme = "dark-ansi";
      statusLine = {
        type = "command";
        command = lib.getExe statusline;
      };
    }
  );
in
{
  home.packages = [
    inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    pkgs.sox # audio record/play CLI (`rec`/`play`) — Claude Code voice mode
  ];

  # Claude Code owns ~/.claude/settings.json (/model, /effort, permission grants
  # all write to it), so it can't be a store symlink. Merge in only the declared
  # keys and leave the rest alone — which also means a /theme change in the app
  # only lasts until the next rebuild.
  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ ! -v DRY_RUN ]]; then
      settings="$HOME/.claude/settings.json"
      mkdir -p "$(dirname "$settings")"
      current=$(cat "$settings" 2>/dev/null || true)
      [[ -n $current ]] || current='{}'
      # Unparseable (caught mid-write?) → skip rather than fail the whole activation
      if ${lib.getExe pkgs.jq} --slurpfile d ${declared} '. * $d[0]' <<<"$current" \
          > "$settings.hm-tmp"; then
        mv "$settings.hm-tmp" "$settings"
      else
        rm -f "$settings.hm-tmp"
        echo "claudeSettings: $settings isn't valid JSON; left it alone" >&2
      fi
    fi
  '';
}
