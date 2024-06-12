# Linux builder configuration for aarch64-darwin
#
# Uses nix-darwin's built-in linux-builder module which runs a NixOS VM
# via QEMU to build aarch64-linux derivations.

{ config, lib, pkgs, ... }:

{
  # Linux builder for aarch64-linux builds (disabled to save 8GB memory)
  # Re-enable when needed for building agent-vm or other Linux derivations
  # nix.linux-builder = {
  #   enable = true;
  #   maxJobs = 4;
  #   config = ({ lib, ... }: {
  #     virtualisation.cores = 4;
  #     virtualisation.memorySize = lib.mkForce 8192;  # 8GB for building NixOS VMs
  #   });
  # };

  # Remote x86_64-linux builder on Hetzner
  nix.distributedBuilds = true;
  nix.buildMachines = [
    {
      hostName = "135.181.179.143";
      sshUser = "justin";
      sshKey = "/Users/justin/.ssh/id_ed25519_hetzner";
      system = "x86_64-linux";
      maxJobs = 4;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
    }
  ];
}
