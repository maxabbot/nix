# modules/home/wm/kanshi.nix — Kanshi automatic display switching for docked laptop setups.
#
# Produces two profiles:
#   undocked  — internal display only
#   docked    — left 1440p | right 1440p, internal below (centred)
#
# Connector names vary by dock/port. Discover them when docked:
#   wlr-randr        (shows connected outputs and their exact names)
#   hyprctl monitors (shows Hyprland's view after a session is running)
{
  lib,
  config,
  ...
}:
let
  cfg = config.custom.hm;
  k = cfg.kanshi;

  hasDocked = k.docked.left != null && k.docked.right != null;
in
{
  options.custom.hm.kanshi = {
    enable = lib.mkEnableOption "kanshi automatic display switching";

    internal = {
      output = lib.mkOption {
        type = lib.types.str;
        default = "eDP-1";
        description = "Connector name of the laptop's internal display.";
      };
      mode = lib.mkOption {
        type = lib.types.str;
        default = "1920x1200@60";
        description = "Mode string for the internal display.";
      };
      scale = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
      };
    };

    docked = {
      left = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Kanshi output criteria for the left external monitor: a connector name (DP-1) or, better, the EDID description from `hyprctl monitors`.";
      };
      leftMode = lib.mkOption {
        type = lib.types.str;
        default = "2560x1440@60";
      };
      right = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Kanshi output criteria for the right external monitor: a connector name (DP-2) or, better, the EDID description from `hyprctl monitors`.";
      };
      rightMode = lib.mkOption {
        type = lib.types.str;
        default = "2560x1440@60";
      };
      # Right monitor sits immediately past the left monitor's width.
      # Update this if leftMode differs from 2560x1440.
      rightPosition = lib.mkOption {
        type = lib.types.str;
        default = "2560,0";
        description = "Position of the right external monitor. Should equal the left monitor's pixel width.";
      };
      # Laptop centred below: x = (leftWidth + rightWidth - laptopWidth) / 2
      # For 2×2560 externals + 1920 internal: (5120 - 1920) / 2 = 1600
      laptopPosition = lib.mkOption {
        type = lib.types.str;
        default = "1600,1440";
        description = "Position of the internal display in docked layout (centred below the two externals).";
      };
    };
  };

  config = lib.mkIf (k.enable && cfg.compositor == "hyprland") {
    services.kanshi = {
      enable = true;
      # `settings` (list of sections) replaces the deprecated `profiles` attrset.
      settings = [
        {
          profile = {
            name = "undocked";
            outputs = [
              {
                criteria = k.internal.output;
                status = "enable";
                mode = k.internal.mode;
                position = "0,0";
                scale = k.internal.scale;
              }
            ];
          };
        }
      ]
      ++ lib.optionals hasDocked [
        {
          profile = {
            name = "docked";
            outputs = [
              {
                criteria = k.docked.left;
                status = "enable";
                mode = k.docked.leftMode;
                position = "0,0";
                scale = 1.0;
              }
              {
                criteria = k.docked.right;
                status = "enable";
                mode = k.docked.rightMode;
                position = k.docked.rightPosition;
                scale = 1.0;
              }
              {
                criteria = k.internal.output;
                status = "enable";
                mode = k.internal.mode;
                position = k.docked.laptopPosition;
                scale = k.internal.scale;
              }
            ];
          };
        }
      ];
    };
  };
}
