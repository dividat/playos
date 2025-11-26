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

  # in MBs
  vmMemory = 1500;
  kioskPct = builtins.ceil(600.0 / vmMemory * 100);

  scopePrefix = "kiosk-test";

  pollIntervalSeconds = 1;
  testImageSizeMB = 50;
  testBlobSizeMB = 30;
in
pkgs.nixosTest {
  name = "kiosk respects memory limits";

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
              server = pkgs.writers.writePython3Bin "hello.py"
                        { libraries = with pkgs.python3Packages; [ flask pillow ]; }
              ''
from flask import Flask, send_file, jsonify
import os
import io
import math
import gc
from PIL import Image
import logging

app = Flask(__name__)

log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)

LAST_PAYLOAD = None
PAYLOAD_TYPE = None
IMAGE_ID = 0
BLOB_ID = 0


@app.route('/', methods=['GET'])
def index():
    return """
<html>
<body>
<h1>Buffer length: <span id='count'>0</span></h1>
<img id='img' style='max-width:500px'/>
<script>
let buf = [];
async function poll() {
    let r = await fetch('/data/get', { method: 'POST' });
    let j = await r.json();
    if (j.type == 'blob') {
        buf.push(j.data);
        document.getElementById('count').innerText = buf.length;
        console.error(`PAGE: Blob ''${j.num} loaded`);
    } else if (j.type == 'image') {
        const im = document.getElementById('img');
        im.onload = () => console.error(`PAGE: Image ''${j.num} loaded`);
        im.src = j.url;
    }
}
setInterval(poll, ${toString pollIntervalSeconds} * 1000);
console.error("PAGE: Main loaded")
</script>
</body>
</html>
"""


@app.route('/settings', methods=['GET'])
def settings():
    return """
<html><body><script>
console.error("PAGE: Settings loaded")
</script></body></html>
"""


@app.route('/data/new/image', methods=['POST'])
def new_image():
    global LAST_PAYLOAD, PAYLOAD_TYPE, IMAGE_ID
    dim = int(math.sqrt(${toString testImageSizeMB} * (1024*1024) / 3))
    pixels = os.urandom(dim*dim)
    img = Image.new('L', (dim, dim))
    img.putdata(pixels)
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    LAST_PAYLOAD = buf.getvalue()
    PAYLOAD_TYPE = 'image'
    IMAGE_ID += 1
    return str(IMAGE_ID)


@app.route('/data/new/blob', methods=['POST'])
def new_data():
    global LAST_PAYLOAD, PAYLOAD_TYPE, BLOB_ID
    rand_bytes = os.urandom(1024*1024*${toString testBlobSizeMB})
    LAST_PAYLOAD = rand_bytes.decode('latin1').encode('latin1').hex()
    PAYLOAD_TYPE = 'blob'
    BLOB_ID += 1
    return str(BLOB_ID)


@app.route('/data/get', methods=['POST'])
def get_data():
    global LAST_PAYLOAD, PAYLOAD_TYPE, IMAGE_ID, BLOB_ID
    gc.collect()  # avoid OOM kill!

    resp = {'type': PAYLOAD_TYPE}

    match PAYLOAD_TYPE:
        case 'blob':
            resp['data'] = LAST_PAYLOAD
            resp['num'] = BLOB_ID
        case 'image':
            resp['url'] = f'/image/{IMAGE_ID}.png'
            resp['num'] = IMAGE_ID

    PAYLOAD_TYPE = None
    return jsonify(resp)


@app.route('/image/<int:i>.png', methods=['GET'])
def serve_image(i):
    global LAST_PAYLOAD
    resp = send_file(io.BytesIO(LAST_PAYLOAD), mimetype='image/png')
    resp.headers['Cache-Control'] = 'public, max-age=3600'
    return resp


app.run(port=${toString serverPort})
              '';
            in
            "${server}/bin/hello.py";
          Restart = "always";
        };
      };

      virtualisation.memorySize = pkgs.lib.mkForce vmMemory;

      boot.kernel.sysctl = {
        "vm.panic_on_oom" = pkgs.lib.mkForce 0;
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
              ${pkgs.run-with-memory-limit}/bin/run-with-memory-limit \
                --scope-prefix ${scopePrefix} \
                --memory-pct ${toString kioskPct} \
                    ${kiosk}/bin/kiosk-browser \
                        ${kioskUrl} ${kioskUrl}settings

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
    import math

    def get_dm_restarts():
        _, restarts_str = machine.systemctl("show display-manager.service -p NRestarts")
        [_, num] = restarts_str.split("NRestarts=")
        return int(num.strip())

    def get_kiosk_pid():
        kiosk_pids = machine.succeed("pgrep --full kiosk-browser | sort -n | head -1")
        return int(kiosk_pids.strip())

    def get_kiosk_memory_usage_mb():
        _, mem_peak_str = machine.systemctl("--user -M alice@.host show '${scopePrefix}-*.scope' --property MemoryPeak --state running --value")
        return int(int(mem_peak_str.strip()) / (1024*1024))

    def kiosk_is_dead(kiosk_pid):
        status, _ = machine.execute(f"ps -p {kiosk_pid}")
        return status != 0

    machine.start()
    machine.wait_for_unit("graphical.target")

    original_kiosk_pid = get_kiosk_pid()

    MAX_KIOSK_MEMORY_MB = ${toString (vmMemory * kioskPct / 100)}
    # kiosk loaded with about:blank uses around 160MB of memory
    MAX_PAGE_MEMORY_MB = MAX_KIOSK_MEMORY_MB - 150

    POLL_INTERVAL = ${toString pollIntervalSeconds}
    IMAGE_SIZE_MB = ${toString testImageSizeMB}
    BLOB_SIZE_MB = ${toString testBlobSizeMB}

    # actual number is smaller, since other things use memory too and there's overhead
    num_images_to_oom = math.ceil(MAX_PAGE_MEMORY_MB / IMAGE_SIZE_MB) + 1
    num_blobs_to_oom = math.ceil(MAX_PAGE_MEMORY_MB / BLOB_SIZE_MB) + 1

    with TestCase("kiosk clears image upon request cache, does not OOM") as t:
        print(f"Going to load {num_images_to_oom} images of size {IMAGE_SIZE_MB}MB")

        for _ in range(num_images_to_oom*2):
            num = machine.succeed("curl --silent --fail -X POST ${kioskUrl}data/new/image")
            if kiosk_is_dead(original_kiosk_pid):
                break

            wait_for_logs(machine, f"PAGE: Image {num.strip()} loaded", timeout=3)

        # display-manager and kiosk did not restart
        t.assertEqual(get_dm_restarts(), 0)
        t.assertEqual(get_kiosk_pid(), original_kiosk_pid)

        # memory usage was never exceeded
        t.assertLess(get_kiosk_memory_usage_mb(), MAX_KIOSK_MEMORY_MB)


    with TestCase("kiosk is killed on OOM, but recovers"):
        print(f"Going to load {num_blobs_to_oom} blobs of size {BLOB_SIZE_MB}MB")
        for _ in range(num_blobs_to_oom):
            num = machine.succeed("curl --silent --fail -X POST ${kioskUrl}data/new/blob")
            if kiosk_is_dead(original_kiosk_pid):
                break

            try:
                wait_for_logs(machine, f"PAGE: Blob {num.strip()} loaded", timeout=10)
            except TimeoutError:
                break

        # ensure it is running again if it was just killed
        machine.wait_for_unit("display-manager.service")
        # mark the time
        checkpoint = wait_for_logs(machine, ".*")

        t.assertGreater(get_dm_restarts(), 0)
        t.assertNotEqual(get_kiosk_pid(), original_kiosk_pid)

        # kiosk loads the page again
        wait_for_logs(machine, "PAGE: Main loaded", since=checkpoint, timeout=20)

        # Can switch to settings, they load
        machine.send_key("ctrl-shift-f12")
        checkpoint = wait_for_logs(machine, "PAGE: Settings loaded", since=checkpoint, timeout=5)
'';
}
