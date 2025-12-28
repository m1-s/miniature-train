{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    # nixos-raspberrypi.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks-nix.url = "github:cachix/git-hooks.nix";
    git-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self
    , nixpkgs
    , nixos-raspberrypi
    , git-hooks-nix
    }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        inherit (self.checks.x86_64-linux.pre-commit-check) shellHook;
      };

      checks.x86_64-linux.pre-commit-check = git-hooks-nix.lib.x86_64-linux.run {
        src = ./.;
        hooks = {
          nixpkgs-fmt.enable = true;
          statix.enable = true;
          deadnix.enable = true;
        };
      };

      nixosConfigurations.rpi5 = nixos-raspberrypi.lib.nixosSystem {
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
                  "libvirtd"
                  "networkmanager"
                  "wheel"
                ];

                openssh.authorizedKeys.keys = [
                  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6W6sqrJAV0JjASRVvr+HMRp3p46UnmKJXbU1MFaySkBCViVVIarey+Od9JsVp8qhOLPNdd060b5Jjbe76nCpFCVhh45+OX7QhVPpluT8yyr6PzOdDvp1kirSiyeeXlr0VfluXGPRSJXhH33GOSyPiXxwVUQ3YxUo4KQVe1q6eAvwX6/UROmMgdnDdvooC2qKO98IKFu0p9zfWtm6WSmtCeMfu38QG+lq8axpPUbYTsDfZ5PZm/QA053Jt+rt8YiohU+cP2hhgSIcVrQOZAYfc7AzzSPRDU0aMdHhJNh+ivX0eRjYKqpkTZclbY0xEOb55mkWdlVs2+sUs0dYuN3oFocADN6RC1qX6vV9GwUjBiWV+jMjRJCnTn5yh8Ht+YbK6I1zVvvYstFjIT1S5RBx81iahBAARs1PCwls3eT06+KZLb1jA1CD8RXl63Dy+m+AmLqBeX8/cyMegv/rUJQRJK+WeCF5u9QCEwT2AaNVmtWXkCSsCxHgorUTvMVW/RkM= m1-s@tower"
                  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINaGspw6myJ5GKHHxN+7jaJWyU1SlVo4nCzDajyJdtvg m1-s@thinkbook"
                ];
              };

              networking = {
                hostName = "miniature-train-rpi";
                #useDHCP = false;
                #interfaces = { wlan0.useDHCP = true; };
              };

              environment.systemPackages = with pkgs; [
                vim
                git
                wget
              ];

              services.openssh = {
                enable = true;
                settings.PasswordAuthentication = false;
              };

              hardware = {
                # bluetooth.enable = true;
                # TODO: check if needed
                # raspberry-pi = {
                #   config = {
                #     all = {
                #       base-dt-params = {
                #         # enable autoprobing of bluetooth driver
                #         # https://github.com/raspberrypi/linux/blob/c8c99191e1419062ac8b668956d19e788865912a/arch/arm/boot/dts/overlays/README#L222-L224
                #         krnbt = {
                #           enable = true;
                #           value = "on";
                #         };
                #       };
                #     };
                #   };
                # };
              };
              system.stateVersion = "25.11";
            }
          )
        ];
      };
    };
}
