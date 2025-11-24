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
              counter = pkgs.writers.writePython3Bin "hello.py"
                        { libraries = [ pkgs.python3Packages.flask ]; }
              ''
from flask import Flask, Response

app = Flask(__name__)


def response(count):
    html = f"""\
<html>
<body>
    <h1>{count}</h1>
    <script>
        function dispatch() {{
            const event = new CustomEvent("play:beforereload", {{
                detail: {{ url: "${kioskUrl}reloaded/{count+1}" }}
            }});
            console.error("PAGE: about to reload");
            window.dispatchEvent(event);
        }}
        console.error("PAGE: Page loaded, counter: {count}");
        setTimeout(dispatch, 5000);
    </script>
</body>
</html>
"""
    return Response(html, mimetype="text/html")


@app.route("/reloaded/<int:num>")
def reloaded(num: int):
    return response(num)


@app.route("/")
def root():
    return reloaded(1)


app.run(host="0.0.0.0", port=${toString serverPort})
              '';
            in
            "${counter}/bin/hello.py";
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

    with TestPrecondition("kiosk handles beforereload and loads specified url"):
        wait_for_logs(machine, "PAGE: Page loaded, counter: 2", timeout=10)
        wait_for_logs(machine, "PAGE: Page loaded, counter: 3", timeout=10)
'';
}
