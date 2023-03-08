{config, pkgs, lib, ... }:
let
  cfg = config.remoteMaintenance;
in
{
  options = {
    remoteMaintenance = with lib; {
      enable = mkEnableOption "Remote maintenance";

      networks = mkOption {
        default = [];
        example = [];
        type = types.listOf types.str;
        description = "ZeroTier networks to join";
      };

      authorizedKeys = mkOption {
        default = [];
        example = [];
        type = types.listOf types.str;
        description = "Public SSH keys authorized to log in";
      };

    };
  };

  config = lib.mkIf config.remoteMaintenance.enable {
    # Enable ZeroTier for remote maintenance
    services.zerotierone = {
      enable = true;
      # from the ext.dividat.com network.
      joinNetworks = cfg.networks;
    };
    # Prevent ZeroTier from running on startup
    systemd.services.zerotierone.wantedBy = lib.mkForce [];

    # Allow remote access via OpenSSH
    services.openssh = {
      enable = true;

      # but not with password
      passwordAuthentication = false;
    };

    # only with these special keys:
    users.users.root.openssh.authorizedKeys.keys = cfg.authorizedKeys;
    
  };
}
