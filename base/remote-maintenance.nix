{config, pkgs, lib, ... }:
let
  cfg = config.playos.remoteMaintenance;
  maintenanceInterface = "ztmntnc";
in
{
  imports = [
    (lib.mkRemovedOptionModule [ "playos" "remoteMaintenance" "networks" ] "A single network is now expected to be set via `playos.remoteMaintenance.network`.")
  ];

  options = {
    playos.remoteMaintenance = with lib; {
      enable = mkEnableOption "Remote maintenance";

      network = mkOption {
        default = null;
        example = "d5e04297a16fa690";
        type = types.str;
        description = "ZeroTier network to join";
      };

      authorizedKeys = mkOption {
        default = [];
        example = [];
        type = types.listOf types.str;
        description = "Public SSH keys authorized to log in";
      };

      requireOptIn = mkOption {
        default = true;
        example = false;
        description = "With required opt-in ZeroTier needs to be started on the machine before remote access is possible";
        type = lib.types.bool;
      };

    };
  };

  config = lib.mkIf cfg.enable {
    # Configure ZeroTier to connect to maintenance network
    services.zerotierone = {
      enable = true;
      joinNetworks = [ cfg.network ];
    };
    # If opt-in is enabled, prevent ZeroTier from running on startup
    systemd.services.zerotierone.wantedBy = lib.mkIf cfg.requireOptIn (lib.mkForce []);
    # Create devicemap to set known interface name
    systemd.services.zerotierone.preStart = lib.mkAfter ''
      echo "${cfg.network}=${maintenanceInterface}" > /var/lib/zerotier-one/devicemap
    '';

    # Allow remote access via OpenSSH
    services.openssh = {
      enable = true;

      # Restrict authentication to authorized keys
      settings.PasswordAuthentication = false;
      settings.KbdInteractiveAuthentication = false;

      # Do not add general firewall exception
      openFirewall = false;

      # Restrict forwarding
      extraConfig = ''
        AllowTcpForwarding local
        X11Forwarding no
        AllowAgentForwarding no
        AllowStreamLocalForwarding no
      '';

    };
    # Only on the ZeroTier maintenance interface
    networking.firewall.interfaces."${maintenanceInterface}".allowedTCPPorts = [ 22 ];
    # Only with the specified authorized keys
    users.users.root.openssh.authorizedKeys.keys = cfg.authorizedKeys;
    
  };
}
