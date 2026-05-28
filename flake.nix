{
  description = "NixOS system configuration — home-desktop / work-laptop / minimal";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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

    stylix = {
      url = "github:danth/stylix";
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
        config.allowUnfree = true;
        overlays = [ (import ./overlays) ];
      };

      # Shared hmArgs applied to every host — override per-host as needed.
      sharedHmArgs = {
        git = {
          name = "Max Abbot";
          email = "abbot.max.nz@gmail.com";
          signingkey = "";
        };
        nvidia = false;
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
              # DP-2: 4K portrait monitor (left); logical size after 90° rotation = 2160x3840
              secondary = "DP-2,3840x2160@60,0x0,1,transform,1";
              # DP-3: primary 1440p gaming monitor (right)
              primary = "DP-3,2560x1440@165,2160x0,1";
              primaryName = "DP-3";
            };
            location = {
              latitude = -43.53;
              longitude = 172.64;
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
            location = {
              latitude = 51.5;
              longitude = -0.1;
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
