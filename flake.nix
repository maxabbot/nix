{
  description = "NixOS system configuration — home-desktop / framework";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Secrets (hosts/common/optional/sops.nix) — same tool as the homelab repo.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      # Its HM module builds on home-manager's mkFirefoxModule; use ours.
      inputs.home-manager.follows = "home-manager";
    };

    # Tracks master, with its version check suppressed in stylix.nix. Not
    # release-26.05: that branch's Zen target has no opacity support (master's
    # opacityHex), so its userChrome paints Zen solid and the translucency in
    # modules/home/zen.nix is lost (checked 2026-10-27). Re-check when the next
    # release branch is cut.
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apollo-flake = {
      url = "github:nil-andreas/apollo-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # LMMS 1.3 packaged from the upstream AppImage — nixpkgs still ships the
    # outdated 1.2.2 stable release, whose LV2 plugin support (Carla/Surge XT)
    # is incomplete. Pre-release: project files saved with it aren't openable
    # in LMMS 1.2.x.
    lmms-appimage = {
      url = "github:Matko802/lmms-appimage-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Native Claude Code binary — updates hourly, ahead of nixpkgs. It's the
    # upstream binary fetched and autoPatchelf'd, so following our unstable
    # set costs no compiling (and no Cachix is configured here anyway) and
    # keeps a third nixpkgs out of flake.lock.
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # DMS plugin registry — only its nix/default.nix package set is used
    # (pinned revs + hashes per plugin; see modules/home/wm/dms-plugins.nix).
    # flake = false so its own nixpkgs input isn't pulled in.
    dms-plugin-registry = {
      url = "github:AvengeMedia/dms-plugin-registry";
      flake = false;
    };

  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nixos-hardware,
      disko,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;

      mkPkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          # Several Electron desktop apps in 26.05 (Slack/Discord/Obsidian/Element/…)
          # still bundle Electron 39, which is EOL and flagged insecure. Allow it.
          # WinBoat 0.9.0 (winboat.nix, framework only) pins Electron 40, likewise EOL.
          permittedInsecurePackages = [
            "electron-39.8.10"
            "electron-40.10.5"
            # Obsidian is held on Electron 42 (productivity.nix): 43 breaks its renderer.
            "electron-42.11.18"
          ];
        };
        overlays = [
          (import ./overlays)
          # Expose the unstable package set as pkgs.unstable.* — used to pull
          # individual fast-moving packages (e.g. Zed) onto an otherwise stable system.
          (_final: _prev: {
            unstable = import inputs.nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
          })
          inputs.lmms-appimage.overlays.default
        ];
      };

      # Shared hmArgs applied to every host — override per-host as needed.
      sharedHmArgs = {
        git = {
          name = "Max Abbot";
          email = "abbot.max.nz@gmail.com";
        };
        nvidia = false;
        kanshi = {
          enable = false;
        };
        # Desktop wallpaper (modules/home/wm/hyprland.nix), set by awww on every
        # output at login.
        wallpaper = ./config/wallpapers/leaves-wall.png;
        # Image for a rotated secondary monitor; null keeps the rendered
        # SHORTCUTS.md cheat-sheet there.
        wallpaperPortrait = null;
        # DMS lock-screen background (modules/home/wm/dms.nix): the rainbow Nix
        # snowflake the Limine menu shows, rendered from the palette.
        lockWallpaper = "${mkPkgs.gruvbox-wallpapers}/rainbow-nix.png";
        # Software KVM (home/max/lan-mouse.nix) — the module-system ignores
        # function-signature defaults for HM args, so the off-default lives here.
        lanMouse = {
          enable = false;
        };
        # Zen profile directory (modules/home/zen.nix). Zen names it randomly on
        # first run, so hosts with an existing profile point at theirs.
        zen = {
          profilePath = "default";
        };
        # Same idea for Thunderbird (modules/home/thunderbird.nix), whose HM
        # module names the profile directory after the profile.
        thunderbird = {
          profileName = "default";
        };
      };

      # Builds a NixosSystem with Home Manager wired in. hostName becomes
      # networking.hostName; machineType ("desktop" | "laptop") reaches both
      # NixOS and HM modules as an argument. hmArgs are passed as
      # extraSpecialArgs to the HM user config.
      mkHost =
        {
          hostName,
          machineType,
          modules,
          hmArgs ? { },
        }:
        lib.nixosSystem {
          inherit system;
          pkgs = mkPkgs;
          specialArgs = { inherit inputs machineType; };
          modules = modules ++ [
            inputs.sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              networking.hostName = hostName;
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";
                extraSpecialArgs =
                  sharedHmArgs
                  // hmArgs
                  // {
                    inherit inputs machineType;
                  };
                users.max = import ./home/max;
              };
            }
          ];
        };
    in
    {
      formatter.${system} = mkPkgs.nixfmt-tree;

      # Built by CI's `nix flake check`: every derivation that patches upstream
      # files with --replace-fail — the DMS shell (modules/home/wm/dms.nix), its
      # greeter (productivity.nix) and the plugins (dms-plugins.nix). A flake
      # update that rewords a patched line then fails on GitHub instead of at
      # the next nixup. CI only builds them when one of their inputs changed
      # (the path list in .github/workflows/ci.yml — keep it in step). framework carries every plugin; the local plugin
      # directories aren't derivations, so there is nothing to build for them.
      checks.${system} =
        let
          fw = inputs.self.nixosConfigurations.framework.config;
          hm = fw.home-manager.users.max;
          plugins = lib.filterAttrs (
            name: file: lib.hasPrefix "dms/plugins/" name && lib.isDerivation file.source
          ) hm.xdg.configFile;
        in
        {
          dms-shell = lib.findFirst (
            p: lib.getName p == "dux-shell"
          ) (throw "checks: no dms-shell in framework's home.packages") hm.home.packages;
          dms-greeter = fw.services.displayManager.dms-greeter.package;
        }
        // lib.mapAttrs' (
          name: file: lib.nameValuePair "dms-plugin-${baseNameOf name}" file.source
        ) plugins;

      devShells.${system}.default = mkPkgs.mkShell {
        name = "nixos-config";
        packages = with mkPkgs; [
          nixfmt-tree
          statix
          deadnix
          nil
          sops
          age
          shellcheck
        ];
        # Point git at the tracked hooks (.githooks/pre-commit runs the fast CI
        # checks on the staged tree).
        shellHook = ''
          git config core.hooksPath .githooks
        '';
      };

      nixosConfigurations = {
        # RTX 40-series desktop — full stack
        home-desktop = mkHost {
          hostName = "home-desktop";
          machineType = "desktop";
          modules = [
            ./hosts/home-desktop
            disko.nixosModules.disko
          ];
          hmArgs = {
            compositor = "hyprland";
            nvidia = true;
            wallpaper = ./config/wallpapers/waterfall-3.jpg;
            wallpaperPortrait = ./config/wallpapers/cave.jpg;
            monitors = {
              # DP-2: 4K portrait monitor (left); 90° rotation + 1.5x scale → logical 1440x2560
              secondary = "DP-2,3840x2160@60,0x0,1.5,transform,1";
              # DP-3: primary 1440p gaming monitor (right), placed past DP-2's 1440 logical
              # width. y = 0 so the two panels' top edges line up.
              primary = "DP-3,2560x1440@165,1440x0,1";
              primaryName = "DP-3";
            };
            # The laptop sits to the right of the desk; its keyboard/mouse are
            # shared via lan-mouse (see home/max/lan-mouse.nix). Swap position
            # to "left" here (and to "right" on the laptop) if it moves. The
            # peer's tailnet IP is pinned: lan-mouse's own DNS client came back
            # empty for the bare MagicDNS name (getent resolves it fine), and
            # with no address the link just times out.
            lanMouse = {
              enable = true;
              peer = "framework";
              position = "right";
              ips = [ "100.87.132.94" ];
              activateOnStartup = true;
            };
            zen.profilePath = "alhlpwpr.Default Profile";
            thunderbird.profileName = "4z8l4vef.default";
          };
        };

        # Framework Laptop 13 Pro (Core Ultra X7 358H, Panther Lake / Arc Xe3) —
        # personal + work daily driver, and home-desktop's lan-mouse peer.
        framework = mkHost {
          hostName = "framework";
          machineType = "laptop";
          modules = [
            ./hosts/framework
            disko.nixosModules.disko
            # Panther Lake (Core Ultra series 3) Framework 13 support: EC kmod,
            # framework-tool, fwupd, fprintd, acpilight, power kernel params.
            nixos-hardware.nixosModules.framework-intel-core-ultra-series3
          ];
          hmArgs = {
            compositor = "hyprland";
            # 2.8K 120 Hz internal panel at 2x. kanshi's internal output, mode
            # and scale default to this string, so its "undocked" profile
            # matches the static Hyprland declaration and there's no scale flash
            # while kanshi starts. Confirm the connector and modes on first boot
            # with `wlr-randr` (the panel is eDP-1 on every Framework 13 so far).
            monitors = {
              primary = "eDP-1,2880x1920@120,0x0,2";
              primaryName = "eDP-1";
              secondary = null;
              # Any other screen (a hot desk, a TV): its preferred mode at auto
              # scale, centred above the panel like the office desk. kanshi's
              # generic "external" profiles keep this and handle the lid.
              fallback = ",preferred,auto-center-up,auto";
            };
            # The Framework gear rather than the Nix snowflake on the lock screen.
            lockWallpaper = "${mkPkgs.gruvbox-wallpapers}/rainbow-framework.png";
            # Kanshi manages the docked/undocked layout automatically.
            # The docked profile is the office desk (two Philips 276B1s,
            # matched by EDID serial, so the dock's connector numbering doesn't
            # matter). A different desk needs its own descriptions from
            # `hyprctl monitors`.
            kanshi = {
              enable = true;
              docked = {
                left = "Philips Consumer Electronics Company PHL 276B1 UK02150032264";
                right = "Philips Consumer Electronics Company PHL 276B1 UK02150032262";
                leftMode = "2560x1440@74.97Hz";
                rightMode = "2560x1440@74.97Hz";
                # Centred below 2×2560 externals at the 1440-wide logical size:
                # (5120 - 1440) / 2 = 1840.
                laptopPosition = "1840,1440";
              };
              # The living-room Samsung TV: it prefers 4K@30 and auto scale
              # gives 1x, so pin 4K@60 at 2x (centred above the panel).
              tv.criteria = "Samsung Electric Company SAMSUNG 0x01000E00";
            };
            # home-desktop's tailnet IP is pinned — see the home-desktop
            # lanMouse comment for why MagicDNS isn't enough.
            lanMouse = {
              enable = true;
              peer = "home-desktop";
              position = "left";
              ips = [ "100.111.189.79" ];
              activateOnStartup = true;
            };
          };
        };
      };
    };
}
