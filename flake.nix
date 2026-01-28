{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    # nixos-raspberrypi.inputs.nixpkgs.follows = "nixpkgs";

    git-hooks-nix.url = "github:cachix/git-hooks.nix";
    git-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";

    agenix-repo.url = "github:ryantm/agenix";
    agenix-repo.inputs.nixpkgs.follows = "nixpkgs";

    srcpd-rust.url = "github:m1-s/srcpd_rust?ref=addLock";
    srcpd-rust.flake = false;
  };

  outputs =
    { self
    , nixpkgs
    , nixos-raspberrypi
    , git-hooks-nix
    , srcpd-rust
    , agenix-repo
    }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [
          self.overlays.default
          agenix-repo.overlays.default
        ];
      };
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        inherit (self.checks.x86_64-linux.pre-commit-check) shellHook;
        packages = with pkgs; [ agenix ];
      };

      packages.x86_64-linux = {
        inherit (pkgs) srcpd-rust;
      };

      checks.x86_64-linux.pre-commit-check = git-hooks-nix.lib.x86_64-linux.run {
        src = ./.;
        hooks = {
          nixpkgs-fmt.enable = true;
          statix.enable = true;
          deadnix.enable = true;
        };
      };

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
                # autologin for local access
                # getty.autologinUser = "root";
                # displayManager.autoLogin = {
                #   enable = true;
                #   user = "root";
                # };
                displayManager.gdm.enable = true;
                desktopManager.gnome.enable = true;
                openssh = {
                  enable = true;
                  settings.PasswordAuthentication = false;
                };
                # xserver = {
                #   enable = true;
                #   # xkb.layout = "us";
                # };
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
                bernhart.password = "";
              };

              security.pam.services.login.allowNullPassword = true;

              nix = {
                settings.trusted-users = [ "@wheel" ];
                extraOptions = ''
                  experimental-features = nix-command flakes
                '';
              };

              environment.systemPackages = with pkgs; [
                vim
                git
                wget
                firefox
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
          src = srcpd-rust;
          cargoHash = "sha256-UXmKHZV82JZslivH+sOdRAl8t6BGH8Su1v2hbplhKjU=";
        };
      };
    };
}
