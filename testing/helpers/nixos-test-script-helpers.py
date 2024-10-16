import subprocess
import unittest
from colorama import Fore, Style
import re

# HACK: create writable cow disk overlay (same as in ./run-in-vm --disk)
def create_overlay(disk, overlay_path):
    subprocess.run(["rm", "-f", overlay_path])
    subprocess.run([
        'qemu-img', 'create',
            '-b', disk, '-F', 'raw',
            '-f', 'qcow2', overlay_path
        ],
        check=True)

class AbstractTestCheck(object):
    def __init__(self, check_kind, test_descr):
        self.check_kind = check_kind
        self.test_descr = test_descr
        self.test_c = unittest.TestCase()

    def print_descr(self, outcome=""):
        print(f"{Style.BRIGHT}[{self.check_kind}] {self.test_descr}... {outcome}")
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

class TestPrecondition(AbstractTestCheck):
    def __init__(self, test_descr):
        super().__init__("TestPrecondition", test_descr)

class TestCase(AbstractTestCheck):
    def __init__(self, test_descr):
        super().__init__("TestCase", test_descr)

def wait_for_logs(vm, regex, unit=None, timeout=10):
    maybe_unit = f"--unit={unit}" if unit else ""
    journal_cmd = f"journalctl {maybe_unit}"
    full_cmd = f"{journal_cmd} | grep '{regex}'"
    try:
        vm.wait_until_succeeds(full_cmd, timeout=timeout)
    except Exception as e:
        print(f"wait_for_logs ({full_cmd}) failed after {timeout} seconds")
        print("Last VM logs:\n")
        _, output = vm.execute(f"{journal_cmd} | tail -30")
        print(output)
        raise e


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
