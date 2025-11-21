let
  pkgs = import ../../pkgs { };
  serverPort = 8080;
  kioskUrl = "http://localhost:${toString serverPort}/";
  kiosk = import ../../kiosk {
    pkgs = pkgs;
    system_name = "PlayOS";
    system_version = "1.0.0";
  };
  inherit (builtins) toString;
in
pkgs.nixosTest {
  name = "Kiosk responds to Play reload events";

  enableOCR = true;

  nodes.machine = { config, ... }: {
      imports = [
        (pkgs.importFromNixos "tests/common/user-account.nix")
      ];

      systemd.services.http-server = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          ExecStart =
            let
              counter = pkgs.writeScript "hello.sh" ''
                #!${pkgs.bash}/bin/bash
                COUNTER_FILE="/tmp/request-counter"
                EMIT_RELOAD="/tmp/emit-reload"

                COUNT=$(cat $COUNTER_FILE || echo 0)
                ((COUNT++))
                echo $COUNT > $COUNTER_FILE
                printf "Request counter is: %d" "$COUNT" >&2

                noreload_response() {
                    cat <<EOF
                        <html>
                        <body>
                            <h1>$COUNT</1>
                            <script>
                                console.error("PAGE: Page loaded, counter: $COUNT")
                            </script>
                        </body>
                        </html>
                EOF
                }

                reload_response() {
                    cat <<EOF
                        <html>
                        <body>
                            <h1>$COUNT</1>
                            <script>
                                function dispatch() {
                                    const event = new CustomEvent("play:beforereload", {});
                                    console.error("PAGE: about to reload");
                                    window.dispatchEvent(event);
                                }
                                console.error("PAGE: Page loaded, counter: $COUNT")
                                setTimeout(dispatch, 5000);
                            </script>
                        </body>
                        </html>
                EOF
                }

                echo -e "HTTP/1.1 200 OK\r"
                echo -e "Content-Type: text/html\r"
                echo -e "\r"

                if [[ -r "$EMIT_RELOAD" ]]; then
                    reload_response
                else
                    noreload_response
                fi
              '';
            in
            "${pkgs.nmap}/bin/ncat -lk -p ${toString serverPort} -c ${counter}";
          Restart = "always";
        };
      };

      virtualisation.qemu.options = [
        "-enable-kvm"
      ];

      services.xserver = let sessionName = "kiosk-browser";
      in {
        enable = true;

        desktopManager = {
          xterm.enable = false;
          session = [{
            name = sessionName;
            start = ''
              ${kiosk}/bin/kiosk-browser \
                ${kioskUrl} ${kioskUrl}

              waitPID=$!
            '';
          }];
        };

        displayManager = {
          # Always automatically log in play user
          lightdm = {
            enable = true;
            greeter.enable = false;
            autoLogin.timeout = 0;
          };

          autoLogin = {
            enable = true;
            user = "alice";
          };

          defaultSession = sessionName;
        };
     };
  };

  extraPythonPackages = ps: [
    ps.colorama
    ps.types-colorama
  ];

  testScript = ''
    ${builtins.readFile ../helpers/nixos-test-script-helpers.py}
    machine.start()
    machine.wait_for_unit("graphical.target")

    with TestPrecondition("kiosk loads the page"):
        wait_for_logs(machine, "PAGE: Page loaded, counter: 1", timeout=10)

    with TestCase("kiosk does not prematurely reload the page") as t:
        try:
            wait_for_logs(machine, "PAGE: Page loaded, counter: [2|3]", timeout=5)
        except TimeoutError:
            # timeout is good
            pass
        else:
            t.fail("Second load happened prematurely!")

    machine.succeed("echo 1 > /tmp/emit-reload")
    machine.systemctl("restart display-manager.service")

    with TestCase("kiosk receives Play event and reloads"):
        # It seems that Chromium does some pre-fretch request followed by a load,
        # so counter jumps from 1->3. Also, kiosk's full reload does a doable
        # load, so subsequent counters also increment by 2. To avoid depending
        # on the internals, we just check that they are incrementing.
        wait_for_logs(machine, "PAGE: Page loaded, counter: [3|4]", timeout=20)
        wait_for_logs(machine, "PAGE: about to reload", timeout=10)
        wait_for_logs(machine, "PAGE: Page loaded, counter: [5|6]", timeout=10)
'';
}
