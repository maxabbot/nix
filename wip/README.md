# wip/

Re-integration recipes for features that have been removed from the active config.
Each `.nix` file describes exactly what to add and where to restore a feature.
Static config/dotfiles that belong to a wip feature live under `wip/config/<name>/`
so they stay colocated with the recipe until re-integration.

| File | Feature | Config files |
|---|---|---|
| `cava.nix` | Cava audio visualizer | `config/cava/` |
| `swaync.nix` | Swaync notification daemon | `config/swaync/` |
| `quickshell.nix` | Quickshell bar (replaces Waybar) | `wip/config/quickshell/` |
| `swayosd.nix` | SwayOSD volume/brightness overlay | — |
| `matugen.nix` | Matugen dynamic theming | `config/matugen/` (still active) |

To re-enable a feature: follow the instructions in the `.nix` file, move any
config files back to `config/<name>/`, and remove the entry from this table.
