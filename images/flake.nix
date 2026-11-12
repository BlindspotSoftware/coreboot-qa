{
  description = "Coreboot QA Test Image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    firmwareci-base-image = {
      url = "github:BlindspotSoftware/firmwareci-base-image/a003a17b66e98c1a571036e99566c8920602bae9";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, flake-utils, nixpkgs, pre-commit-hooks, firmwareci-base-image, ... }:
    let
      system = "x86_64-linux";
      fsType = "ext4";
      inherit (firmwareci-base-image.outputs) baseConfig;

      corebootToolsConfig = { pkgs, ... }: {
        environment.systemPackages = with pkgs; [
          coreboot-utils
        ];
      };

      # grub for both bios (seabios) and uefi (edk2) payloads
      bootConfig = { lib, ... }: {
        boot.loader = {
          systemd-boot.enable = lib.mkForce false;
          grub = {
            enable = lib.mkForce true;
            device = "/dev/sda";
            efiSupport = true;
            efiInstallAsRemovable = true;
            extraConfig = ''
              serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1
              terminal_input serial console
              terminal_output serial console
            '';
          };
        };

        # Serial console for kernel
        boot.kernelParams = [ "console=ttyS0,115200" ];

        # make-disk-image mounts the ESP on /boot, the base image wants /boot/EFI
        fileSystems = lib.mkForce {
          "/" = {
            device = "/dev/disk/by-label/nixos";
            fsType = "ext4";
          };
          "/boot" = {
            device = "/dev/disk/by-label/ESP";
            fsType = "vfat";
          };
        };
      };

      generateDiskImage = { config, fsType, pkgs }:
        import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
          inherit config fsType pkgs;
          inherit (nixpkgs) lib;
          partitionTableType = "hybrid";
          additionalSpace = "0";
        };
    in
    {
      nixosConfigurations = {
        qemu = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            baseConfig
            bootConfig
            corebootToolsConfig
          ];
        };
      };
    } // flake-utils.lib.eachSystem [ system ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        checks = {
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              nixpkgs-fmt.enable = true;
              statix.enable = true;
            };
          };
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [ statix ];
          shellHook = ''
            ${self.checks.${system}.pre-commit-check.shellHook}
          '';
        };

        packages = {
          qemu = generateDiskImage {
            inherit fsType pkgs;
            inherit (self.nixosConfigurations.qemu) config;
          };

          default = self.packages.${system}.qemu;
        };
      });
}
