let
  pkgs = import ../../pkgs { };
in
pkgs.testers.runNixOSTest {
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
        # Config folder created after service started up
        node.wait_until_succeeds('ls /var/lib/zerotier-one/', timeout=5)
        # Interface created with fixed name, this may take several seconds on the test VM
        node.wait_until_succeeds('ip link show ztmntnc', timeout=20)
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
    defaultConnectionSetting.wait_for_unit('multi-user.target')
    is_zt_operational(autoConnected)
  '';
}
