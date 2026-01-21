# This is a template for a RAUC install-check hook that can be used to perform
# compatibility adjustments to the system in "emergency" situations.
#
# The script is expected to exit with a failing status to always abort the
# installation of the dummy RAUC bundle, which itself is without utility.
#
# By creating a PlayOS release that uses this hook, it is possible to perform
# compatibility fixes to the "fleet" as part of the update process, without
# having remote access to the machines.
{ pkgs ? import ../pkgs {} }:
let
  # Note: all tools used here must be in PATH (i.e. part of environment.systemPackages)
  # in the BOOTED system! Do NOT use references like "${pkgs.gawk}/bin/awk",
  # because they would point to non-existant nix packages.
  #
  # As a last resort, you can attempt to locate binaries in e.g. `/run/current-system/sw/bin`
  compatScriptChecked = pkgs.writeShellApplication {
    name = "compat-install-script";
    text = ''
      # Ensure the script always exits with an exit code >10
      # even on unexpected failures. This is neede
      # because that indicates to RAUC to abort installation.
      trap "exit 101" EXIT

      echo "== Running compat install-check script"

      if ! [[ "''${1:-}" == "install-check" ]]; then
          echo "Expected to be run with 'install-check'"
          exit 1
      fi

      echo "== Step 1: Figuring out slot names of booted and other"

      # `rauc status` cannot be used during installation and `RAUC_SLOT_*` env
      # variables are not provided for install-check hooks, so we determine the
      # "booted" and "other" systems by analyzing the mountpoints.
      other_system=$(lsblk -o LABEL,MOUNTPOINTS -P | grep 'LABEL="system.' | grep 'MOUNTPOINTS=""' | cut -f2 -d'"') || echo ""
      booted_system=""

      if [[ "$other_system" == "system.a" ]]; then
        booted_system="system.b"
      elif [[ "$other_system" == "system.b" ]]; then
        booted_system="system.a"
      else
          echo "Failed to determine other system (other_system='$other_system'), lsblk output:"
          lsblk -o LABEL,MOUNTPOINTS || true
          exit 101
      fi

      echo "Booted system is: $booted_system"
      echo "Other system is:  $other_system"
      echo ""

      # `export` to avoid unused var error in shellcheck
      export other_system_disk=/dev/disk/by-label/$other_system
      export booted_system_disk=/dev/disk/by-label/$booted_system

      echo "== Step 2: Performing compat fixes"

      ###
      ### DEFINE COMPAT STEPS HERE
      ###
      ### Use the {booted|other}_system and {booted|other}_system_disk variables
      ### as needed.

      echo "== Step N: Make sure the scripts fails"
      echo "Applied compatibility settings, waiting for next update" 1>&2
      exit 101
    '';
    };
in
pkgs.runCommand
    "compat-install-script-local.sh"
    {
      allowedReferences = []; # avoid accidentally referring to any nix package
    }
    # Replace shebang on first line with #!/bin/sh - this will run using the
    # host system's packages, not the packages from the system image!
    # Note: /bin/sh is an alias for bash on nixOS
    ''
    cp "${pkgs.lib.getExe compatScriptChecked}" $out
    sed -i '1 s|^.*$|#!/bin/sh|' $out
    ''
