{
  # Toggle to true once device IDs and addresses have been populated.
  enable = true;

  # Optional overrides for the shared folder.
  folderId = "sync";
  folderLabel = "Sync";

  mac = {
    name = "macbook";
    deviceId = "5YOWEAS-TTC2RM2-6HMYJWX-RHAODS2-UPVM7R6-WURLA7T-CTCPPXO-HOQCDAG";
    # Tailscale address
    addresses = [ "tcp://100.124.249.54:22000" "quic://100.124.249.54:22000" ];
  };

  hetzner = {
    name = "hetzner";
    deviceId = "KTZMXD7-4ZQEJSH-PME6CTL-KAHNIRU-FUYM6YM-3BTE4AL-SXIKZBZ-RUFZKAB";
    # Tailscale address
    addresses = [ "tcp://100.73.239.5:22000" "quic://100.73.239.5:22000" ];
  };

  stignore = ''
(?d).DS_Store
(?d)Thumbs.db

# Build outputs
(?d)node_modules
(?d)target
(?d)dist
(?d).venv
(?d)__pycache__
(?d).direnv
(?d)result

# VCS metadata
(?d).git
(?d).svn
(?d).hg
  '';
}
