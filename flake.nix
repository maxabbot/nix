{
  description = "NixOS system configuration — home-desktop / work-laptop / minimal";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Stylix has no release-26.05 branch yet (lags the nixpkgs release), so track
    # master and suppress its version check in stylix.nix. Switch to
    # github:nix-community/stylix/release-26.05 once that branch exists.
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

    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Native Claude Code binary — updates hourly, ahead of nixpkgs
    claude-code-nix.url = "github:sadjow/claude-code-nix";

  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nixos-hardware,
      disko,
      zen-browser,
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
          permittedInsecurePackages = [ "electron-39.8.10" ];
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
        # Software KVM (home/max/lan-mouse.nix) — the module-system ignores
        # function-signature defaults for HM args, so the off-default lives here.
        lanMouse = {
          enable = false;
        };
      };

      # Builds a NixosSystem with Home Manager wired in.
      # hmArgs are passed as extraSpecialArgs to the HM user config.
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
          specialArgs = {
            inherit
              inputs
              nixos-hardware
              zen-browser
              hostName
              machineType
              ;
          };
          modules = modules ++ [
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs =
                  sharedHmArgs
                  // hmArgs
                  // {
                    inherit inputs;
                  };
                users.max = import ./home/max;
              };
            }
          ];
        };
    in
    {
      formatter.${system} = mkPkgs.nixfmt-tree;

      devShells.${system}.default = mkPkgs.mkShell {
        name = "nixos-config";
        packages = with mkPkgs; [
          nixfmt-tree
          statix
          deadnix
          nil
        ];
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
            machineType = "desktop";
            compositor = "hyprland";
            nvidia = true;
            monitors = {
              # HDMI-A-1: Philips FTV 4K TV (far left); 4K@60Hz, scale 2 → logical 1920 wide
              tertiary = "HDMI-A-1,3840x2160@60,0x0,2";
              # DP-2: 4K portrait monitor (centre); 90° rotation + 1.5x scale → logical 1440 wide
              secondary = "DP-2,3840x2160@60,1920x0,1.5,transform,1";
              # DP-3: primary 1440p gaming monitor (right), placed past DP-2's 1440 logical width
              primary = "DP-3,2560x1440@165,3360x0,1";
              primaryName = "DP-3";
            };
            location = {
              latitude = -43.53;
              longitude = 172.64;
            };
            # work-laptop sits to the right of the desk; its keyboard/mouse are
            # shared via lan-mouse (see home/max/lan-mouse.nix). Swap position
            # to "left" here (and to "right" on work-laptop) if the laptop moves.
            lanMouse = {
              enable = true;
              peer = "work-laptop";
              position = "right";
              # ips = [ "192.168.x.x" ]; # set if the router doesn't resolve hostnames
              # activateOnStartup = true; # flip once the link is confirmed working
            };
          };
        };

        # Development laptop — no GPU/gaming
        work-laptop = mkHost {
          hostName = "work-laptop";
          machineType = "laptop";
          modules = [
            ./hosts/work-laptop
            disko.nixosModules.disko
          ];
          hmArgs = {
            machineType = "laptop";
            compositor = "hyprland";
            monitors = {
              primary = null;
              secondary = null;
            };
            # Kanshi manages the docked/undocked layout automatically.
            # To find the real connector names: boot docked, then run `wlr-randr`.
            # Look for the "name:" field on each output — update left/right below.
            # The two Philips PHL0947 monitors are identical in model; kanshi
            # distinguishes them by connector name (DP-x), NOT by description.
            kanshi = {
              enable = true;
              internal = {
                output = "eDP-1"; # Lenovo internal panel — almost universal
                mode = "1920x1200@60";
              };
              docked = {
                left = null; # TODO: replace with connector name from wlr-randr
                right = null; # TODO: replace with connector name from wlr-randr
                # leftMode / rightMode default to 2560x1440@60 — override if refresh differs
                # rightPosition defaults to "2560,0" (left monitor width)
                # laptopPosition defaults to "1600,1440" (centred below 2×2560 externals)
              };
            };
            location = {
              latitude = 51.5;
              longitude = -0.1;
            };
            lanMouse = {
              enable = true;
              peer = "home-desktop";
              position = "left";
              # Router doesn't resolve DHCP hostnames, so pin the IP (wlo1
              # lease as of 2026-07-08 — give both machines DHCP reservations
              # in the router to keep these stable).
              ips = [ "192.168.0.235" ];
            };
          };
        };

        # Home-desktop stack in a QEMU VM — no NVIDIA/CUDA/fancontrol
        vm = mkHost {
          hostName = "vm";
          machineType = "desktop";
          modules = [
            ./hosts/vm
            disko.nixosModules.disko
          ];
          hmArgs = {
            machineType = "desktop";
            compositor = "hyprland";
            monitors = {
              primary = "Virtual-1,1920x1080@60,0x0,1";
              secondary = null;
              primaryName = "Virtual-1";
            };
            location = {
              latitude = -43.53;
              longitude = 172.64;
            };
          };
        };

        # Minimal — base packages only, headless (no compositor)
        minimal = mkHost {
          hostName = "minimal";
          machineType = "server";
          modules = [ ./hosts/minimal ];
          hmArgs = {
            machineType = "server";
            compositor = "none";
            monitors = {
              primary = null;
              secondary = null;
            };
            location = {
              latitude = 0.0;
              longitude = 0.0;
            };
          };
        };
      };
    };
}
