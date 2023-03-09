{config, pkgs, lib, ... }:
let
  cfg = config.playos.remoteMaintenance;
in
{
  options = {
    playos.remoteMaintenance = with lib; {
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

  config = lib.mkIf cfg.enable {
    services.zerotierone = {
      enable = true;
      joinNetworks = cfg.networks;
    };
    # Prevent ZeroTier from running on startup, it is started manually
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
