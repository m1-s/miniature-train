{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    # nixos-raspberrypi.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks-nix.url = "github:cachix/git-hooks.nix";
    git-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";
    srcpd-rust.url = "github:m1-s/srcpd_rust?ref=addLock";
    srcpd-rust.flake = false;
  };

  outputs =
    { self
    , nixpkgs
    , nixos-raspberrypi
    , git-hooks-nix
    , srcpd-rust
    }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ self.overlays.default ];
      };
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        inherit (self.checks.x86_64-linux.pre-commit-check) shellHook;
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
          {
            imports = with nixos-raspberrypi.nixosModules; [
              raspberry-pi-5.base
            ];
          }
          (
            { pkgs, ... }:
            {
              time.timeZone = "Europe/Berlin";
              security.sudo.wheelNeedsPassword = false;

              networking = {
                useNetworkd = true;
                wireless.iwd = {
                  enable = true;
                  settings.Settings.AutoConnect = true;
                };
                useDHCP = false;
              };
              systemd.tmpfiles.rules = [
                "f /var/lib/iwd/foo.psk 0600 root root - [Security]\nPassphrase=bar"
              ];
              systemd.network = {
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
              services.resolved.enable = true;
              networking.hostName = "miniature-train-rpi";

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

              users.users.m1-s = {
                isNormalUser = true;
                extraGroups = [
                  "networkmanager"
                  "wheel"
                ];

                openssh.authorizedKeys.keys = [
                  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6W6sqrJAV0JjASRVvr+HMRp3p46UnmKJXbU1MFaySkBCViVVIarey+Od9JsVp8qhOLPNdd060b5Jjbe76nCpFCVhh45+OX7QhVPpluT8yyr6PzOdDvp1kirSiyeeXlr0VfluXGPRSJXhH33GOSyPiXxwVUQ3YxUo4KQVe1q6eAvwX6/UROmMgdnDdvooC2qKO98IKFu0p9zfWtm6WSmtCeMfu38QG+lq8axpPUbYTsDfZ5PZm/QA053Jt+rt8YiohU+cP2hhgSIcVrQOZAYfc7AzzSPRDU0aMdHhJNh+ivX0eRjYKqpkTZclbY0xEOb55mkWdlVs2+sUs0dYuN3oFocADN6RC1qX6vV9GwUjBiWV+jMjRJCnTn5yh8Ht+YbK6I1zVvvYstFjIT1S5RBx81iahBAARs1PCwls3eT06+KZLb1jA1CD8RXl63Dy+m+AmLqBeX8/cyMegv/rUJQRJK+WeCF5u9QCEwT2AaNVmtWXkCSsCxHgorUTvMVW/RkM= m1-s@tower"
                  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINaGspw6myJ5GKHHxN+7jaJWyU1SlVo4nCzDajyJdtvg m1-s@thinkbook"
                ];
              };

              nix.settings.trusted-users = [ "@wheel" ];

              environment.systemPackages = with pkgs; [
                vim
                git
                wget
              ];

              services.openssh = {
                enable = true;
                settings.PasswordAuthentication = false;
              };

              system.stateVersion = "25.11";
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
