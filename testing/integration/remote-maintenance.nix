let
  pkgs = import ../../pkgs { };
in
pkgs.nixosTest {
  name = "remote maintenance";

  nodes = {
    defaultConnectionSetting = { config, pkgs, ... }: {
      imports = [ ../../base/remote-maintenance.nix ];
      config = {
        playos.remoteMaintenance = {
          enable = true;
          network = "d5e04297a16fa690";
          authorizedKeys = [];
        };
      };
    };

    autoConnected = { config, pkgs, ... }: {
      imports = [ ../../base/remote-maintenance.nix ];
      config = {
        playos.remoteMaintenance = {
          enable = true;
          network = "d5e04297a16fa690";
          authorizedKeys = [];
          requireOptIn = false;
        };
      };
    };
  };

  testScript = ''
    def is_zt_operational(node):
        node.wait_for_unit('zerotierone.service')
        # Config folder created
        node.succeed('ls /var/lib/zerotier-one/')
        # Interface created with fixed name
        node.succeed('ip link show ztmntnc')
        # Firewall is configured for SSH on ZT interface
        node.succeed('iptables -nvL | grep ztmntnc | grep "tcp dpt:22"')

    # Default connection setting does not start ZT service on its own
    defaultConnectionSetting.start()
    defaultConnectionSetting.wait_for_unit('multi-user.target')
    defaultConnectionSetting.fail('ls /var/lib/zerotier-one/')
    defaultConnectionSetting.fail('ip link show ztmntnc')
    defaultConnectionSetting.systemctl('start zerotierone.service')
    is_zt_operational(defaultConnectionSetting)

    # Auto-connected makes ZT operational on its own
    autoConnected.start()
    autoConnected.wait_for_unit('zerotierone.service')
    is_zt_operational(autoConnected)
  '';
}
