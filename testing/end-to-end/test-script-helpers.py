import subprocess
import unittest
# colorama is used by test-driver too
from colorama import Fore, Style

# HACK: create writable cow disk overlay (same as in ./run-in-vm --disk)
# TODO: how to create this before the test script without a derivation?
def create_overlay(disk, overlay_path):
    subprocess.run(["rm", "-f", overlay_path])
    subprocess.run([
        # TODO: use /nix/store'd qemu path
        'qemu-img', 'create',
            '-b', disk, '-F', 'raw',
            '-f', 'qcow2', overlay_path
        ],
        check=True)

# TODO: upgrade this into a magic proxy class that makes every
# assert* call loggable, to make debugging easier
class TestCase(object):
    def __init__(self, test_descr):
        self.test_descr = test_descr
        self.test_c = unittest.TestCase()

    def print_descr(self, outcome=""):
        print(f"{Style.BRIGHT}[TestCase] {self.test_descr}... {outcome}")
        print(Style.RESET_ALL)

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


def wait_for_logs(vm, regex, unit=None, timeout=10):
    maybe_unit = f"--unit={unit}" if unit else ""
    journal_cmd = f"journalctl --reverse {maybe_unit}"
    try:
        vm.wait_until_succeeds(f"{journal_cmd} | grep '{regex}'", timeout=timeout)
    except Exception as e:
        _, output = vm.execute(f"{journal_cmd} | head -30")
        print("Last VM logs:\n")
        print(output)
        raise e


def expose_local_port(vm, port):
    # forward external `port` to 127.0.0.1:port to allow external
    # access to internal services in PlayOS

    # enable NAT on loopback
    vm.succeed("sysctl net.ipv4.conf.all.route_localnet=1")

    # forward the port
    vm.succeed("iptables -t nat -A PREROUTING -p tcp " + \
                f"--dport {port} -j DNAT --to-destination 127.0.0.1:{port}")

    # open the port in the firewall
    vm.succeed(f"iptables -A INPUT -p tcp --dport {port} -j ACCEPT")
    vm.succeed("systemctl reload firewall")

# with exponential back-off
async def retry_until_no_exception(func, retries=3, sleep=3.0):
    import asyncio
    total_retries = retries
    while True:
        retries -= 1
        try:
            return (await func())
        except Exception as e:
            if (retries > 0):
                print(f"Func failed with {e}, sleeping for {sleep} seconds")
                await asyncio.sleep(sleep)
                sleep *= 2
            else:
                print(f"Func failed with {e}, giving up after {total_retries}")
                raise e
