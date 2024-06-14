let
  pkgs = import ../../pkgs { };
  serverPort = 8080;
  proxyPort = 8888;
  kiosk = import ../../kiosk {
    pkgs = pkgs;
    system_name = "PlayOS";
    system_version = "1.0.0";
  };
  toString = builtins.toString;
in
pkgs.nixosTest {
  name = "proxy-test";

  nodes = {
    client = { config, ... }: {
      imports = [
        (pkgs.importFromNixos "tests/common/user-account.nix")
        (pkgs.importFromNixos "tests/common/x11.nix")
      ];

      # Override is needed to enable in test VM, see connman tests:
      # https://github.com/NixOS/nixpkgs/blob/1772251828be641110eb9a47ef530a1252ba211e/nixos/tests/connman.nix#L47-L52
      services.connman.enable = pkgs.lib.mkOverride 0 true;

      # We need a graphical environment and regular user for the kiosk browser
      services.xserver = {
        enable = true;
      };
      test-support.displayManager.auto.user = "alice";

      environment.systemPackages = [
        pkgs.connman
        kiosk
      ];
    };
  };

  testScript = ''
    start_all()

    # Wait for X11 and connman, required by kiosk
    client.wait_for_x()
    client.wait_for_unit("connman.service")

    with subtest('kiosk-browser uses configured proxy'):
      service_name = client.succeed("connmanctl services | head -1 | awk '{print $3}'").strip(' \t\n\r')
      client.succeed(f"connmanctl config {service_name} proxy manual http://user:p4ssw0rd@theproxy:${toString proxyPort}")

      kiosk_result = client.execute(
        'su - alice -c "kiosk-browser http://thecloud:${toString serverPort} http://foo.xyz" 2>&1',
        check_return=False,
        check_output=True,
        timeout=10
      )

      # Ideally here we would check if starting the kiosk resulted in a request
      # to a proxy and HTTP server running in separate VMs. Unfortunately it
      # has proven difficult to set up such a test with connman on the client,
      # and there are very few NixOS tests using connman to take inspiration
      # from.
      #
      # So for now we simply test whether the proxy has been picked up and
      # configured in the Qt framework.

      if "Set proxy to theproxy:${toString proxyPort}" not in kiosk_result[1]:
        print(kiosk_result[1])
        raise AssertionError("Expected kiosk logs to contain info about configured proxy.")
  '';

}

