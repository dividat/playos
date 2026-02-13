let
  pkgs = import ../../pkgs { };

in
pkgs.testers.runNixOSTest {
  name = "collect debug info script tests";

  nodes = {
    machine = { config, ... }: {
      imports = [
      ];

      config = {
        environment.systemPackages = with pkgs; [ playos-diagnostics ];
        services.connman.enable = pkgs.lib.mkOverride 0 true; # disabled in runNixOSTest by default
      };
    };
  };

  extraPythonPackages = ps: [
    ps.colorama
    ps.types-colorama
  ];

  testScript =
''
${builtins.readFile ../helpers/nixos-test-script-helpers.py}
from contextlib import contextmanager
from pathlib import Path
import tarfile
from datetime import datetime
import gzip
import urllib.parse

######### Test helpers

def run_diagnostic_script(extra_params="", check_error=True):
    # Note: we exclude UPDATE diagnostics by default, because they require
    # a fully functional EFI/GRUB/RAUC setup and are best tested on actual
    # hardware or in end-to-end tests.
    (exit_code, out) = machine.execute(f"playos-diagnostics --exclude UPDATE {extra_params}")

    if check_error and exit_code != 0:
      raise RuntimeError(f"playos-diagnostics failed ({exit_code=})!")

    return (exit_code, out)

@contextmanager
def extracted_archive(path):
  with tempfile.TemporaryDirectory() as temp_dir:
      # 'r:*' handles transparent compression
      with tarfile.open(path, "r:*") as tar:
          tar.extractall(path=temp_dir)

      yield Path(temp_dir)

@contextmanager
def diagnostic_output(extra_params="", check_error=True):
    # /tmp/shared is a magic folder shared between VM and host,
    # reachable as machine.shared_dir on the host
    with tempfile.NamedTemporaryFile(dir=machine.shared_dir, suffix=".tar.gz") as f:
        f = Path(f.name)
        code, _ = run_diagnostic_script(f"-o /tmp/shared/{f.name} {extra_params}", check_error=check_error)

        with extracted_archive(str(machine.shared_dir / f.name)) as a:
            yield code, a


# Get file contents based on glob pattern, optionally decompressing if the
# glob pattern ends in .gz
def get_file_contents(archive_dir, glob_str, t=None):
    match = list(archive_dir.glob(glob_str))
    t.assertEqual(len(match), 1,
        f"Archive missing {glob_str} file?")

    fp = match[0]

    if str(glob_str).endswith(".gz"):
      open_f = lambda p: gzip.open(p, mode="rt")
    else:
      open_f = lambda p: open(p, mode="r")

    with open_f(fp) as f:
        contents = f.read()
        return contents


########## Tests

start_all()
machine.wait_for_unit("multi-user.target")

with TestCase("script outputs a valid gziped tar archive to stdout"):
    run_diagnostic_script("> /tmp/diag.tar.gz")
    machine.succeed("mkdir -p /tmp/diag")
    machine.succeed("tar xvf /tmp/diag.tar.gz -C /tmp/")
    machine.succeed("ls /tmp/playos-diagnostics-*/collection.log")

ALL_DIAGNOSTIC_TYPES = [ t.lower() for t in run_diagnostic_script("--list-types")[1].split() ]

with TestCase("archive contents contain expected structure") as t:
    with diagnostic_output() as (_, tmpdir):
      top_level_items = list(tmpdir.iterdir())

      # exactly 1 top-level directory
      t.assertEqual(len(top_level_items), 1)
      top_dir = top_level_items[0]
      t.assertIn("playos-diagnostics-", top_dir.name)

      # contains expected files and dir structure
      files_and_dirs = { h.name for h in top_dir.glob("*") }
      expected_files_and_dirs = { 'data', "collection.log" }

      t.assertSetEqual(expected_files_and_dirs, files_and_dirs)

      output_diagnostic_type_dirs = (top_dir / "data").glob("*")

      t.assertSetEqual(
        { d.name for d in output_diagnostic_type_dirs },
        # UPDATE is excluded in these tests, see run_diagnostic_script
        set(ALL_DIAGNOSTIC_TYPES) - { 'update' }
      )

      # for each diagnostic type, we expect at least one diagnostic file produced
      for dir in output_diagnostic_type_dirs:
        # check at least one file in directory
        t.assertGreater(len(list(dir.glob("*"))), 1)


with TestCase("logs are collected according to --since limits") as t:
    machine.succeed('echo RECENT_TEST_LOG | systemd-cat -t TEST') # journald
    oldest_expected_date = datetime.fromisoformat(machine.succeed(
      'date --date="12 seconds ago" --rfc-3339=seconds | sed "s/ /T/"').strip())

    with diagnostic_output('--since "10 seconds ago"') as (_, tmpdir):
        contents = get_file_contents(
            tmpdir, "playos-diagnostics-*/data/logs/journald.log.gz", t=t)

        t.assertIn("RECENT_TEST_LOG", contents)

        for line in contents.splitlines():
            ts = datetime.fromisoformat(line.split(" ")[0].strip())
            t.assertGreater(ts, oldest_expected_date,
               f"Logs contain entries with timestamps older than expected, line: {line}")

with TestCase("proxy passwords are masked in connman output") as t:
    machine.wait_until_succeeds("connmanctl services | grep ethernet")

    ethernet_service_id = machine.succeed("connmanctl services | awk '/ethernet/ {print $NF}' | head -n 1").strip()

    # Configure a proxy
    proxy_user = "walter@vogelwei.de"
    proxy_pass = urllib.parse.quote(r"Ch@os:The/or&y|'$(id)\"\\", safe="")
    proxy_host = "192.168.1.5:8080"
    machine.succeed(f"connmanctl config {ethernet_service_id} proxy manual 'http://{proxy_user}:{proxy_pass}@{proxy_host}'")

    with diagnostic_output() as (_, tmpdir):
        contents = get_file_contents(
            tmpdir, 
            "playos-diagnostics-*/data/network/connmanctl_service_properties.txt", 
            t=t
        )

        t.assertNotIn(proxy_pass, contents, 
            "The proxy password was found in cleartext!.")
            
        expected_mask = f"http://<MASKED_USER>:<MASKED_PASSWORD>@{proxy_host}"
        t.assertIn(expected_mask, contents, 
            f"The expected masked string '{expected_mask}' was not found.")


with TestCase("--minimal flag excludes logs") as t:
    with diagnostic_output('--minimal') as (_, tmpdir):
        match = list(tmpdir.glob("playos-diagnostics-*/data/logs/"))
        t.assertEqual(match, [])


with TestCase("--exclude excludes custom types") as t:
    with diagnostic_output('--exclude NETWORK') as (_, tmpdir):
        match = list(tmpdir.glob("playos-diagnostics-*/data/network/"))
        t.assertEqual(match, [])


with TestCase("command error exit codes are propagated up") as t:
    # create a faulty device and bind it to /etc/os-release to ensure all reads error out
    machine.succeed("echo '0 2048 error' | dmsetup create faulty_device")
    machine.succeed("mount --bind /dev/mapper/faulty_device /etc/os-release")

    with diagnostic_output(check_error=False) as (exit_code, tmpdir):
        t.assertGreater(exit_code, 100)

        contents = get_file_contents(tmpdir, "playos-diagnostics-*/collection.log", t=t)
        t.assertIn("ERR command failed", contents)
        t.assertIn("Warning: some diagnostic commands failed", contents)

    # remove the bind mount
    machine.succeed("umount /etc/os-release")


with TestCase("commands that hang are timed out") as t:
    # bind-mount /etc/os-release to an empty pipe to block reads forever
    machine.succeed("mkfifo /tmp/empty-pipe")
    machine.succeed("mount --bind /tmp/empty-pipe /etc/os-release")

    # excluding STATS, because the blocked bind mount also makes systemctl hang
    with diagnostic_output('--cmd-timeout 5s --exclude STATS', check_error=False) as (exit_code, tmpdir):
        t.assertGreater(exit_code, 100)

        contents = get_file_contents(tmpdir, "playos-diagnostics-*/collection.log", t=t)
        t.assertIn("timeout: sending signal TERM", contents)
        t.assertIn("ERR command failed", contents)
        t.assertIn("Warning: some diagnostic commands failed", contents)

    # remove the bind mount
    machine.succeed("umount /etc/os-release")
'';

}
