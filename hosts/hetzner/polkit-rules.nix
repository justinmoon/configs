{ config, pkgs, lib, ... }:

{
  # Polkit rules to allow justin user (and GitHub runners) to manage services without sudo
  # This bypasses the NoNewPrivileges restriction in systemd services
  security.polkit.extraConfig = ''
    // Allow justin to reload systemd daemon
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.reload-daemon" &&
          subject.user == "justin") {
        return polkit.Result.YES;
      }
    });
    
    // Allow justin to get unit status and properties
    polkit.addRule(function(action, subject) {
      if ((action.id == "org.freedesktop.systemd1.get-unit" ||
           action.id == "org.freedesktop.systemd1.get-unit-by-pid" ||
           action.id == "org.freedesktop.systemd1.get-unit-processes") &&
          subject.user == "justin") {
        return polkit.Result.YES;
      }
    });
  '';
}