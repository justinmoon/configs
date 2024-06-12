{ config, pkgs, lib, ... }:

{
  # Bitcoin Core service (pruned mode)
  # Using "bitcoind" as the instance name creates service bitcoind-bitcoind
  # So we'll stick with mainnet but create an alias
  services.bitcoind."mainnet" = {
    enable = true;
    
    # Pruned mode - keeps only recent blocks (about 10GB total)
    prune = 2000;  # Keep 2GB of block data
    
    # Extra configuration
    extraConfig = ''
      # Performance
      dbcache=4096
      
      # Network
      maxconnections=125
      maxuploadtarget=5000
      
      # Mempool
      maxmempool=300
      mempoolexpiry=72
      
      # Misc
      server=1
      rpcbind=127.0.0.1
      rpcallowip=127.0.0.1
    '';
  };

  # Create an alias for the service
  systemd.services.bitcoind = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
    };
    requires = [ "bitcoind-mainnet.service" ];
    after = [ "bitcoind-mainnet.service" ];
  };

  # Open firewall for Bitcoin P2P
  # Bitcoin P2P works fine outbound-only; no need to open 8333 publicly

  # Install bitcoin-cli wrapper (don't include raw bitcoind package to avoid conflicts)
  environment.systemPackages = [ 
    (pkgs.writeShellScriptBin "bitcoin-cli" ''
      exec sudo -u bitcoind-mainnet ${pkgs.bitcoind}/bin/bitcoin-cli -datadir=/var/lib/bitcoind-mainnet "$@"
    '')
    (pkgs.writeShellScriptBin "bitcoind-status" ''
      systemctl status bitcoind-mainnet
    '')
  ];
}