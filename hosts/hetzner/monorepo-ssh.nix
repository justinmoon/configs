{ config, lib, pkgs, ... }:

let
  sshKeyPath = "/home/justin/.ssh/monorepo_deploy";
in
{
  age.secrets.monorepo-deploy-key = {
    file = ../../secrets/monorepo-deploy-key.age;
    mode = "0600";
    owner = "justin";
    group = "users";
    path = sshKeyPath;
  };

  # Ensure the .ssh directory exists with strict permissions.
  systemd.tmpfiles.rules = [
    "d /home/justin/.ssh 0700 justin users -"
  ];

  programs.ssh.knownHosts."monorepo-prod" = {
    hostNames = [ "5.161.204.22" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOBIlmi1pI29pIc12ZNHwr+3v0euftst7BsfF2odKHNq";
  };

  programs.ssh.knownHosts."monorepo-staging" = {
    hostNames = [ "178.156.146.77" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIvM6kZ1/VejnklgVgVzQrp5YUTGDimzr69UWQ3kjZr5";
  };
}
