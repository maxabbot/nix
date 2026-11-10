# modules/home/wm/kanshi.nix — Kanshi automatic display switching for docked laptop setups.
#
# Produces three profiles:
#   undocked    — internal display only (at its docked position)
#   docked      — left 1440p | right 1440p, internal below (centred)
#   docked-lid  — docked with the internal display off. Both docked profiles
#                 match the same outputs, so kanshi only picks docked by itself;
#                 the lid switch binds in hyprland.lua switch between them
#                 (kanshictl), and fail harmlessly when undocked.
#   external    — the internal display plus any one other output (a hot desk,
#                 a TV). Only eDP-1 is pinned: the other keeps what Hyprland's
#                 catch-all rule (monitors.fallback) gave it — preferred mode,
#                 auto scale, centred above. kanshi prefers the exact profiles,
#                 and the docked pair is three outputs, so this never shadows it.
#   external-lid — the same with the internal display off, for the lid binds.
#   tv / tv-lid  — like external/external-lid, but for one known screen (kanshi.tv)
#                 that needs a pinned mode/scale: a TV whose preferred mode is
#                 4K@30 and whose auto scale is 1. Centred directly above the
#                 internal panel, so the cursor crosses up from anywhere on its
#                 top edge. Listed before external so kanshi picks it first.
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

  # The internal panel defaults to the host's monitors.primary string
  # ("NAME,MODE,POSITION,SCALE"), so "undocked" matches the static Hyprland
  # declaration and the panel is only described once.
  primary = map lib.strings.trim (lib.splitString "," cfg.monitors.primary);
  fromPrimary =
    n: fallback: if cfg.monitors.primary != null then builtins.elemAt primary n else fallback;

  hasTv = k.tv.criteria != null;

  # Logical width/height of a "WxH@Hz" mode at a scale.
  logical =
    mode: scale:
    let
      wh = lib.splitString "x" (lib.head (lib.splitString "@" mode));
    in
    map (d: builtins.floor (builtins.fromJSON d / scale + 0.5)) wh;
  internalPos = map lib.toInt (
    lib.splitString "," (if hasDocked then k.docked.laptopPosition else "0,0")
  );
  internalW = lib.head (logical k.internal.mode k.internal.scale);
  tvSize = logical k.tv.mode k.tv.scale;
  tvPosition = "${toString (lib.head internalPos + (internalW - lib.head tvSize) / 2)},${
    toString (lib.last internalPos - lib.last tvSize)
  }";

  tvOutput = {
    criteria = k.tv.criteria;
    status = "enable";
    mode = k.tv.mode;
    position = tvPosition;
    scale = k.tv.scale;
  };

  externals = [
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
  ];
in
{
  options.custom.hm.kanshi = {
    enable = lib.mkEnableOption "kanshi automatic display switching";

    internal = {
      output = lib.mkOption {
        type = lib.types.str;
        default = fromPrimary 0 "eDP-1";
        defaultText = lib.literalMD "the connector in `custom.hm.monitors.primary`, else `eDP-1`";
        description = "Connector name of the laptop's internal display.";
      };
      mode = lib.mkOption {
        type = lib.types.str;
        default = fromPrimary 1 "1920x1200@60";
        defaultText = lib.literalMD "the mode in `custom.hm.monitors.primary`, else `1920x1200@60`";
        description = "Mode string for the internal display.";
      };
      scale = lib.mkOption {
        type = lib.types.float;
        # + 0.0: monitors strings write integral scales as "2", and the type is float.
        default = builtins.fromJSON (fromPrimary 3 "1") + 0.0;
        defaultText = lib.literalMD "the scale in `custom.hm.monitors.primary`, else `1.0`";
      };
    };

    tv = {
      criteria = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Kanshi criteria (EDID description from `hyprctl monitors`) for a TV/screen that gets its own pinned mode and scale, centred above the internal panel.";
      };
      mode = lib.mkOption {
        type = lib.types.str;
        default = "3840x2160@60";
      };
      scale = lib.mkOption {
        type = lib.types.float;
        default = 2.0;
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
    # kanshi only reads its config at start, so a rebuild that changes the
    # profiles left the running daemon on the old set (kanshictl switch then
    # fails with "Profile not found"). Restart it whenever the config changes.
    systemd.user.services.kanshi.Unit.X-Restart-Triggers = [
      config.xdg.configFile."kanshi/config".source
    ];

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
                # Alone, its position is irrelevant, so keep the docked one.
                # Hyprland restores each output's last kanshi position on
                # replug: an undocked 0,0 here sits under the returning
                # left monitor (also 0,0) until kanshi re-applies docked,
                # long enough for Hyprland's overlap warning to fire.
                position = if hasDocked then k.docked.laptopPosition else "0,0";
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
            outputs = externals ++ [
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
        {
          profile = {
            name = "docked-lid";
            outputs = externals ++ [
              {
                criteria = k.internal.output;
                status = "disable";
              }
            ];
          };
        }
      ]
      ++ lib.optionals hasTv [
        {
          profile = {
            name = "tv";
            outputs = [
              {
                criteria = k.internal.output;
                status = "enable";
                mode = k.internal.mode;
                position = if hasDocked then k.docked.laptopPosition else "0,0";
                scale = k.internal.scale;
              }
              tvOutput
            ];
          };
        }
        {
          profile = {
            name = "tv-lid";
            outputs = [
              {
                criteria = k.internal.output;
                status = "disable";
              }
              tvOutput
            ];
          };
        }
      ]
      # Internal first, so the wildcard can only take the other output. The
      # non-lid profile comes first: kanshi picks the first match by itself.
      ++ [
        {
          profile = {
            name = "external";
            outputs = [
              {
                criteria = k.internal.output;
                status = "enable";
                mode = k.internal.mode;
                position = if hasDocked then k.docked.laptopPosition else "0,0";
                scale = k.internal.scale;
              }
              {
                criteria = "*";
                status = "enable";
              }
            ];
          };
        }
        {
          profile = {
            name = "external-lid";
            outputs = [
              {
                criteria = k.internal.output;
                status = "disable";
              }
              {
                criteria = "*";
                status = "enable";
              }
            ];
          };
        }
      ];
    };
  };
}
