# Hardware configuration for OrbStack VM
# OrbStack provides a lightweight VM environment with virtio devices
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # OrbStack uses virtio for disks
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_blk" "virtio_scsi" "virtio_net" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # Root filesystem - OrbStack manages this
  fileSystems."/" = {
    device = "/dev/vda";
    fsType = "ext4";
  };

  # OrbStack automatically mounts /Users from macOS host
  # No need to configure - it's handled by OrbStack

  # Platform
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
