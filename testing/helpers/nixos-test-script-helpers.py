import subprocess
import unittest
from colorama import Fore, Style
import re
import sys
import http.server
import multiprocessing as mp
import tempfile
import atexit
import time


# HACK: create writable cow disk overlay (same as in ./run-in-vm --disk)
def create_overlay(disk, overlay_path):
    subprocess.run(["rm", "-f", overlay_path])
    subprocess.run([
        'qemu-img', 'create',
            '-b', disk, '-F', 'raw',
            '-f', 'qcow2', overlay_path
        ],
        check=True)

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

class AbstractTestCheck(object):
    def __init__(self, check_kind, test_descr):
        self.check_kind = check_kind
        self.test_descr = test_descr
        self.test_c = unittest.TestCase()

    def print_descr(self, outcome=""):
        eprint(f"{Style.BRIGHT}[{self.check_kind}] {self.test_descr}... {outcome}")
        eprint(Style.RESET_ALL)

    def print_ok(self):
        self.print_descr(outcome=f"{Fore.GREEN}OK!")

    def print_fail(self):
        self.print_descr(outcome=f"{Fore.RED}Fail!")

    def __enter__(self):
        self.print_descr()
        return self.test_c

    def __exit__(self, exc_type, exc_value, traceback):
        if (exc_type is None and exc_value is None):
            self.print_ok()
        else:
            self.print_fail()

        return False # signals to re-raise the exception

class TestPrecondition(AbstractTestCheck):
    def __init__(self, test_descr):
        super().__init__("TestPrecondition", test_descr)

class TestCase(AbstractTestCheck):
    def __init__(self, test_descr):
        super().__init__("TestCase", test_descr)

# Wait until journactl contains a log entry with a message matching the `regex`
# or time out. Can be optionally filtered by `since` and `unit, with the same
# semantics as the journactl flags.
#
# On success, returns the timestamp of the _latest_ journactl entry matching the
# query, which can be used for filter further queries with `since`.
#
# WARNING: Note that `journactl` is left-inclusive, so if you have a journal like this:
#
#       timestamp=1 A
#       timestamp=1 B
#       timestamp=2 C
#
#  then
#
#       ts = wait_for_logs(vm, 'B')      # succeeds, ts=1
#       wait_for_logs(vm, 'A', since=ts) # succeeds, even though event A _does not follow event B_
#
# even with microsecond precision, this can happen if log entries are produced
# rapidly.
def wait_for_logs(vm, regex, unit=None, since=None, timeout=10):
    maybe_unit = f"--unit={unit}" if unit else ""
    maybe_since = f"--since='{since}'" if since else ""

    # Note: it would be better to use short-monotonic or at least
    # short-iso-precise, but `journalctl --since` ONLY accepts this format...
    journal_cmd_without_grep = f"journalctl -o short-precise -q {maybe_unit} {maybe_since}"
    journal_cmd_base = f"{journal_cmd_without_grep} --grep '{regex}'"

    # This is done in awkward way since using both -n and --grep implies
    # --reverse in journalctl, which combined with --follow makes no sense at
    # all.
    # The `|| true` avoids a pipefail when --follow is closed by head.
    # The `grep .` is to ensure exit code is non-zero if output is empty
    full_cmd = f"""{journal_cmd_base} -n 1 \
                || (({journal_cmd_base} --follow || true) | head -1 | grep .)
    """
    status, out = vm.execute(full_cmd, timeout=timeout)
    if status == 0:
        last_line = out.strip().split("\n")[-1]
        time = last_line.strip().split(f" {vm.name} ")[0].strip()
        return time
    elif status == 124: # specified in timeout man pages
        _, output = vm.execute(f"{journal_cmd_without_grep} -n 30")
        error_message = f"wait_for_logs ({journal_cmd_base}) timed out after {timeout} seconds"
        last_logs_message = f"Last logs without regex:\n{output}"
        full_err_message = f"{error_message}\n{last_logs_message}"
        raise TimeoutError(full_err_message)
    else:
        raise RuntimeError(f"wait_for_logs ({full_cmd}) exited with non-zero exit code ({status}) - invalid regex or since?")


def get_first_connman_service_name(vm):
    return vm.succeed("connmanctl services | head -1 | awk '{print $3}'").strip()


def configure_proxy(vm, proxy_url):
    with TestPrecondition("Set HTTP proxy settings via connman") as t:
        # the output will also contain service types, filtered out below
        services = vm.succeed("connmanctl services").strip().split()
        default_service = None
        for s in services:
            if re.match("ethernet_.*_cable", s):
                info = vm.succeed(f"connmanctl services {s}")
                # default IP assigned to Guest VMs started with `-net user`
                if "Address=10.0.2.15" in info:
                    default_service = s
                    break

        if default_service is None:
            t.fail("Unable to find default interface among connman services")

        vm.succeed(f"connmanctl config {default_service} --proxy manual {proxy_url}")


class HTTPStubServer:
    def __init__(self, port):
        d = tempfile.TemporaryDirectory(delete=False)
        atexit.register(d.cleanup)
        with open(f"{d.name}/index.html", "w") as f:
            f.write("Hello world\n")

        class Handler(http.server.SimpleHTTPRequestHandler):
            def __init__(self, *args, **kwargs):
                super().__init__(*args, directory=d.name, **kwargs)

        self._server = http.server.HTTPServer(
            ("", port),
            Handler
        )
        self.port = port
        self.http_root = d.name
        self._process = None

    def is_running(self):
        return self._process is not None and self._process.is_alive()

    def stop(self):
        if self.is_running():
            self._process.terminate()
            self._process.join()

    def start(self):
        if not self.is_running():
            print(f"Starting HTTP server on port {self.port}")
            # Running as a separate process to avoid GIL
            self._process = mp.Process(target=self._server.serve_forever, daemon=True)
            self._process.start()


def wait_until_passes(test, retries=10, sleep=1):
    while True:
        try:
            return test()
        except Exception as e:
            if retries > 0:
                time.sleep(sleep)
                retries -= 1
            else:
                raise e
