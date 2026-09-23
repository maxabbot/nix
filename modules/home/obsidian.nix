# modules/home/obsidian.nix — Obsidian, themed by Stylix's obsidian target.
#
# HM's per-vault management (programs.obsidian.vaults) is deliberately unused:
# it replaces .obsidian/appearance.json with a /nix/store symlink, and the
# Personal vault is a git repo that tracks that file, so the symlink would be
# committed and pushed to other machines. Instead, the Stylix target still
# renders its CSS snippet and appearance settings into
# programs.obsidian.defaultSettings, and the activation step below copies them
# into every vault Obsidian knows about (from obsidian.json) as plain files —
# the snippet into .obsidian/snippets/, the settings merged into
# appearance.json with the snippet enabled. Obsidian can still save its own
# appearance changes; the next activation re-applies these keys on top.
{
  lib,
  config,
  pkgs,
  ...
}:
let
  gui = config.custom.hm.compositor != "none";
  defaults = config.programs.obsidian.defaultSettings;
  snippets = builtins.filter (s: s.text != null) (
    lib.optionals (defaults.cssSnippets != null) defaults.cssSnippets
  );
  # Stylix's baseFontSize is its point size (11), but Obsidian reads the key
  # as pixels against a 16 px default, which shrank all note text. Keep only
  # the font families.
  appearance = (pkgs.formats.json { }).generate "obsidian-appearance.json" (
    removeAttrs (lib.optionalAttrs (defaults.appearance != null) defaults.appearance) [ "baseFontSize" ]
  );
  snippetFiles = map (s: {
    inherit (s) name;
    file = pkgs.writeText "${s.name}.css" s.text;
  }) snippets;
  jq = lib.getExe pkgs.jq;
in
{
  config = lib.mkIf gui {
    programs.obsidian.enable = true;

    home.activation.obsidianStylix = lib.hm.dag.entryAfter [ "obsidian" ] ''
      obsidianConfig="${config.xdg.configHome}/obsidian/obsidian.json"
      if [ -f "$obsidianConfig" ]; then
        ${jq} -r '.vaults[]?.path' "$obsidianConfig" | while IFS= read -r vault; do
          [ -d "$vault/.obsidian" ] || continue
          run mkdir -p "$vault/.obsidian/snippets"
          ${lib.concatMapStrings (s: ''
            run install -m644 ${s.file} "$vault/.obsidian/snippets/${s.name}.css"
          '') snippetFiles}
          appearanceFile="$vault/.obsidian/appearance.json"
          [ -s "$appearanceFile" ] || echo '{}' > "$appearanceFile"
          tmp="$(mktemp)"
          run ${jq} --slurpfile add ${appearance} \
            --argjson names '${builtins.toJSON (map (s: s.name) snippetFiles)}' \
            '. * $add[0] | .enabledCssSnippets = (((.enabledCssSnippets // []) + $names) | unique)' \
            "$appearanceFile" > "$tmp"
          run install -m644 "$tmp" "$appearanceFile"
          rm -f "$tmp"
        done
      fi
    '';
  };
}
