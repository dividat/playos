let
  pkgs = import ../../pkgs { };
in
pkgs.nixosTest {
  name = "rauc statusfile recovery";

  nodes = {
    client = { config, pkgs, ... }: {
      imports = [ ../../base/self-update ];
      config = {
        playos.selfUpdate = {
          enable = true;
          updateCert = pkgs.writeText "dummy.pem"  "";
        };
      };
    };
  };

  testScript = ''
    import time

    def reset():
      client.execute("rm /boot/status.ini*")

    client.start()

    #
    # Leave alone a good status.ini
    #
    client.succeed('printf "one\ntwo\n" > /boot/status.ini')
    client.succeed('printf "three\nfour\n" > /boot/status.ini.ABCDEFG')
    client.shutdown()
    client.start()
    client.wait_for_unit("statusfile-recovery.service")
    client.succeed('grep two /boot/status.ini')
    client.succeed('test -f /boot/status.ini.ABCDEFG')

    #
    # Replace an empty status.ini with latest alternative
    #
    reset()
    client.succeed('touch /boot/status.ini')
    client.succeed('printf "three\nfour\n" > /boot/status.ini.ABCDEFG')
    time.sleep(1)
    client.succeed('printf "five\nsix\n" > /boot/status.ini.9B8D7F6')
    client.shutdown()
    client.start()
    client.wait_for_unit("statusfile-recovery.service")
    client.succeed('grep five /boot/status.ini')
    client.succeed('test -f /boot/status.ini.ABCDEFG')
    client.fail('test -f /boot/status.ini.9B8D7F6')

    #
    # Leave alone an empty status.ini with no good alternative
    #
    reset()
    client.succeed('touch /boot/status.ini')
    client.succeed('touch /boot/status.ini.ABCDEFG')
    time.sleep(1)
    client.succeed('touch /boot/status.ini.9B8D7F6')
    client.shutdown()
    client.start()
    client.wait_for_unit("statusfile-recovery.service")
    client.succeed('test ! -s /boot/status.ini')
    client.succeed('test -f /boot/status.ini.ABCDEFG')
    client.succeed('test -f /boot/status.ini.9B8D7F6')
  '';
}
