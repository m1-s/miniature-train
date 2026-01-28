{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    # nixos-raspberrypi.inputs.nixpkgs.follows = "nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";

    git-hooks-nix.url = "github:cachix/git-hooks.nix";
    git-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";

    agenix-repo.url = "github:ryantm/agenix";
    agenix-repo.inputs.nixpkgs.follows = "nixpkgs";

    srcpd-rust-repo.url = "github:m1-s/srcpd_rust?ref=addLock";
    srcpd-rust-repo.flake = false;
  };

  outputs =
    { self
    , nixpkgs
    , nixos-raspberrypi
    , flake-utils
    , git-hooks-nix
    , srcpd-rust-repo
    , agenix-repo
    }:
    flake-utils.lib.eachDefaultSystem
      (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            self.overlays.default
            agenix-repo.overlays.default
          ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          inherit (self.checks.${system}.pre-commit-check) shellHook;
          packages = with pkgs; [ agenix ];
        };

        packages = {
          inherit (pkgs) srcpd-rust;
          rocrail = pkgs.callPackage ./rocrail.nix { };
        };

        checks.pre-commit-check = git-hooks-nix.lib.x86_64-linux.run {
          src = ./.;
          hooks = {
            nixpkgs-fmt.enable = true;
            statix.enable = true;
            deadnix.enable = true;
          };
        };
      }) // {
      nixosConfigurations.default = nixos-raspberrypi.lib.nixosSystem {
        specialArgs = { inherit nixpkgs nixos-raspberrypi; };
        modules = [
          agenix-repo.nixosModules.default
          {
            imports = with nixos-raspberrypi.nixosModules; [
              raspberry-pi-5.base
            ];
          }
          (
            { config, pkgs, ... }:
            {
              time.timeZone = "Europe/Berlin";
              security.sudo.wheelNeedsPassword = false;
              nixpkgs.overlays = [ self.overlays.default ];

              networking = {
                hostName = "miniature-train-rpi";
                # useNetworkd = true;
                # wireless.iwd = {
                #   enable = true;
                #   settings.Settings.AutoConnect = true;
                # };
                # useDHCP = false;
              };

              systemd = {
                tmpfiles.rules = [
                  "L+ /var/lib/iwd/Organico3.psk 0600 root root - ${config.age.secrets.wifi.path}"
                ];
                network = {
                  enable = true;
                  networks."25-wireless" = {
                    matchConfig.Name = "wlan0";
                    address = [ "192.168.178.107/24" ];
                    gateway = [ "192.168.178.1" ];
                    networkConfig.DHCP = "no";
                    # Helps with "Dormant" status if the signal blips
                    linkConfig.RequiredForOnline = "routable";
                  };
                };
              };

              services = {
                resolved.enable = true;
                displayManager.gdm.enable = true;
                desktopManager.gnome.enable = true;
                openssh = {
                  enable = true;
                  settings.PasswordAuthentication = false;
                };
              };

              fileSystems = {
                "/boot/firmware" = {
                  device = "/dev/disk/by-label/FIRMWARE";
                  fsType = "vfat";
                  options = [
                    "noatime"
                    "noauto"
                    "x-systemd.automount"
                    "x-systemd.idle-timeout=1min"
                  ];
                };
                "/" = {
                  device = "/dev/disk/by-label/NIXOS_SD";
                  fsType = "ext4";
                  options = [ "noatime" ];
                };
              };

              users.users = {
                m1-s = {
                  isNormalUser = true;
                  extraGroups = [
                    "networkmanager"
                    "wheel"
                  ];

                  openssh.authorizedKeys.keys = [
                    (import ./keys.nix).m1-s
                  ];
                };

                # easy local login
                bernhard = {
                  isNormalUser = true;
                  extraGroups = [
                    "networkmanager"
                    "wheel"
                  ];
                };
              };

              security.pam.services.login.allowNullPassword = true;

              nix = {
                settings.trusted-users = [ "@wheel" ];
                extraOptions = ''
                  experimental-features = nix-command flakes
                '';
              };

              environment.systemPackages =
                let
                  srcpdConf = pkgs.writeText "srcpd.conf" ''
                    [srcp]
                    port = 4303
                  '';
                  startSrcpd = pkgs.writeShellScriptBin "start-srcpd" ''
                    ${pkgs.srcpd-rust}/bin/srcpd ${srcpdConf}
                  '';
                in
                with pkgs; [
                  vim
                  git
                  wget
                  firefox
                  rocrail
                  srcpd-rust
                  tmate
                  htop
                  startSrcpd
                ];

              system.stateVersion = "25.11";

              age.secrets = {
                wifi.file = ./secrets/wifi.age;
              };

              # set the wifi region or not all wifis will be shown
              networking.wireless.iwd.settings.General.Country = "DE";
              networking.localCommands = ''
                ${pkgs.iw}/bin/iw reg set DE
              '';
            }
          )
        ];
      };

      overlays.default = _: final: {
        srcpd-rust = final.rustPlatform.buildRustPackage {
          name = "srcpd-rust";
          src = srcpd-rust-repo;
          cargoHash = "sha256-UXmKHZV82JZslivH+sOdRAl8t6BGH8Su1v2hbplhKjU=";
        };
        rocrail = final.callPackage ./rocrail.nix { };
      };
    };
}
