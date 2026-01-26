#!@python3@/bin/python

import argparse
from dataclasses import dataclass
from enum import Enum
import hashlib
import subprocess
import os
import os.path
import tempfile
import textwrap
import sys
import urllib.request as request
import shlex

UNSIGNED_RAUC_BUNDLE = "@unsignedRaucBundle@"
INSTALLER_ISO = "@installer@"
LIVE_ISO = "@live@"
DOCS = "@docs@"
VERSION = "@version@"
FULL_PRODUCT_NAME = "@fullProductName@"
SAFE_PRODUCT_NAME = "@safeProductName@"

# Certificate installed on system
UPDATE_CERT = "@updateCert@"

# This is the Certificate for the dummy key used during building the bundle
DUMMY_BUILD_CERT = "@dummyBuildCert@"

DEPLOY_URL = "@deployUrl@"
UPDATE_URL = "@updateUrl@"
KIOSK_URL = "@kioskUrl@"

RAUC = "@rauc@/bin/rauc"
AWS_CLI = "@awscli@/bin/aws"


TMPDIR = "/tmp"

@dataclass
class Artifact:
    """An artifact to be included for the version on the dist host."""
    human_name: str
    file_name: str
    local_path: str
    include_in_summary: bool

    @property
    def url(self) -> str:
        return join_url(UPDATE_URL, VERSION, self.file_name)

    def summarize(self) -> str:
        return textwrap.dedent(f"""
            {self.human_name} URL: {self.url}
            {self.human_name} checksum (SHA256): {compute_sha256(self.local_path)}""")


# from http://code.activestate.com/recipes/577058/
def _query_continue(question, default=False):
    valid = {"yes": True, "y": True, "ye": True, "no": False, "n": False}
    if default == None:
        prompt = " [y/n] "
    elif default == True:
        prompt = " [Y/n] "
    elif default == False:
        prompt = " [y/N] "
    else:
        raise ValueError("invalid default answer: '%s'" % default)
    while 1:
        sys.stdout.write(question + prompt)
        choice = input().lower()
        if default is not None and choice == '':
            return default
        elif choice in valid.keys():
            return valid[choice]
        else:
            sys.stdout.write("Please respond with 'yes' or 'no'")

def compute_sha256(filepath):
    hash = hashlib.sha256()
    buff = bytearray(128 * 1024)
    mem_view = memoryview(buff)
    with open(filepath, "rb", buffering=0) as f:
        for n in iter(lambda : f.readinto(mem_view), 0):
            hash.update(mem_view[:n])
    return hash.hexdigest()

def run_command(args, dry_run=False, **kwargs):
    """
    Run a command in a subprocess. If dry_run is True, prints commands instead of executing.
    """
    if dry_run:
        # Quote if needed to output complete, usable commands
        cmd_str = ' '.join(shlex.quote(str(arg)) for arg in args)
        print_status("DRY-RUN", cmd_str, color=StatusColor.YELLOW)
        return

    subprocess.run(args, **kwargs)

def create_signed_rauc_bundle(key, cert, out):
    with tempfile.NamedTemporaryFile(
            mode="w", delete=False, dir=TMPDIR) as combined_keyring:

        # Create a keyring that contains the dummy and real certificate
        with open(DUMMY_BUILD_CERT,
                  "r") as dummy_cert, open(cert, "r") as output_cert:
            combined_keyring.write(dummy_cert.read())
            combined_keyring.write(output_cert.read())
            combined_keyring.close()

        try:
            subprocess.run(
                [
                    RAUC,
                    "--key",
                    key,
                    "--cert",
                    cert,
                    # will be used to check input and output bundle (for some reason...)
                    "--keyring",
                    combined_keyring.name,
                    "resign",
                    UNSIGNED_RAUC_BUNDLE,
                    out
                ],
                stderr=subprocess.PIPE,
                stdout=subprocess.DEVNULL,
                check=True)
        except subprocess.CalledProcessError as err:
            print(err.stderr)
            raise

def _main(opts):

    mode_msg = " (DRY RUN)" if opts.dry_run else ""
    print(f"Deploying {FULL_PRODUCT_NAME} {VERSION}{mode_msg}:\n")

    output_cert = UPDATE_CERT if opts.override_cert == None else opts.override_cert

    with tempfile.TemporaryDirectory(
            prefix="playos-signed-release", dir=TMPDIR) as release_tmp_dir:

        # Sign RAUC bundle (and verify signature)
        signed_bundle_path = os.path.join(release_tmp_dir, f"{SAFE_PRODUCT_NAME}-{VERSION}.raucb")
        create_signed_rauc_bundle(key=opts.key, cert=output_cert, out=signed_bundle_path)

        # Print deployment givens and wait for confirmation
        print("Update URL:\t%s" % UPDATE_URL)
        print("Deploy URL:\t%s" % DEPLOY_URL)
        print("Kiosk URL:\t%s" % KIOSK_URL)

        subprocess.run(
            [RAUC, "info", "--keyring", output_cert, signed_bundle_path],
            stderr=subprocess.DEVNULL,
            check=True)

        if not opts.dry_run and not _query_continue("\nContinue?"):
            print("Aborted.")
            exit(1)


        # Gather artifacts to deploy for this version
        bundle = Artifact(
            human_name = "RAUC Bundle",
            file_name = f"{SAFE_PRODUCT_NAME}-{VERSION}.raucb",
            local_path = signed_bundle_path,
            include_in_summary = False
        )
        manual = Artifact(
            human_name = "Manual",
            file_name = f"{SAFE_PRODUCT_NAME}-manual-{VERSION}.pdf",
            local_path = os.path.join(DOCS, "user-manual.pdf"),
            include_in_summary = True
        )
        artifacts = [ bundle, manual ]

        if INSTALLER_ISO:
            installer_iso_filename = f"{SAFE_PRODUCT_NAME}-installer-{VERSION}.iso"
            artifacts.append(Artifact(
                human_name = "Installer",
                file_name = installer_iso_filename,
                local_path = os.path.join(INSTALLER_ISO, "iso", installer_iso_filename),
                include_in_summary = True
            ))

        if LIVE_ISO:
            live_iso_filename = f"{SAFE_PRODUCT_NAME}-live-{VERSION}.iso"
            artifacts.append(Artifact(
                human_name = "Live System",
                file_name = live_iso_filename,
                local_path = os.path.join(LIVE_ISO, "iso", live_iso_filename),
                include_in_summary = False
            ))


        # Print deployment plan
        print("DEPLOYMENT PLAN")
        print("===============")
        for artifact in artifacts:
            print(f"  - {artifact.human_name}: {artifact.file_name}")
        print()

        # Deploy the version's artifacts
        for artifact in artifacts:
            run_command(
                [
                    AWS_CLI, "s3", "cp", artifact.local_path, join_url(DEPLOY_URL, VERSION, artifact.file_name),
                    "--acl", "public-read"
                ],
                dry_run=opts.dry_run,
                check=True)

        if not opts.skip_latest:
            # Deploy the latest file
            latest_file = os.path.join(release_tmp_dir, "latest")
            with open(latest_file, 'w') as latest:
                latest.write(VERSION + "\n")
            run_command(
                [
                    AWS_CLI,
                    "s3",
                    "cp",
                    latest_file,
                    join_url(DEPLOY_URL, "latest"),
                    "--acl",
                    "public-read",
                    "--cache-control",
                    "max-age=0"
                ],
                dry_run=opts.dry_run,
                check=True)

            # Create copy of latest manual at fixed name
            run_command(
                [
                    AWS_CLI,
                    "s3",
                    "cp",
                    # We have to re-upload this file; copying within bucket is faster, but does not allow setting headers
                    manual.local_path,
                    join_url(DEPLOY_URL, "manual-latest.pdf"),
                    "--acl",
                    "public-read",
                    "--cache-control",
                    "max-age=0",
                    "--content-disposition",
                    "attachment; filename=\"%s\"" % manual.file_name
                ],
                dry_run=opts.dry_run,
                check=True)

        print()
        print("CHECKS")
        print("======\n")
        verify(
            f"Latest version has been updated",
            lambda: request.urlopen(join_url(UPDATE_URL, "latest"), timeout=5).read().decode().strip(),
            VERSION,
            skip=opts.skip_latest or opts.dry_run)

        verify(
            f"Bundle is accessible",
            lambda: request.urlopen(request.Request(join_url(UPDATE_URL, VERSION, bundle.file_name), method="HEAD"), timeout=5).status,
            200,
            skip=opts.dry_run)

        summary = "\n".join(
            artifact.summarize()
            for artifact in artifacts
            if artifact.include_in_summary or opts.verbose
        )
        print()
        print("DEPLOYMENT SUMMARY")
        print("==================")
        print(summary)


        exit(0)

def verify(description, check, expected, skip=False):
    if skip:
        print_status("SKIP", description)
        return

    try:
        actual = check()
        if actual == expected:
            print_status("OK", description, color=StatusColor.GREEN)
        else:
            print_status("FAIL", description, f"Expected '{expected}', got '{actual}'", color=StatusColor.RED)
    except Exception as e:
        print_status("FAIL", description, f"Exception: {e}", color=StatusColor.RED)

def print_status(status_label, description, text="", color=None):
    status = status_label if color == None else f"\033[{color.value}m{status_label}\033[0m"
    print(f"{status} [{description}] {text}")

class StatusColor(Enum):
    RED = 91
    GREEN = 92
    YELLOW = 93

def join_url(base, *parts):
    """Join a URL from the base and parts, stripping any existing slashes from the parts."""
    return '/'.join(
        [base.rstrip('/')] + [part.strip('/') for part in parts])

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=f"Deploy {FULL_PRODUCT_NAME} update")
    parser.add_argument('-v', '--version', action='version', version=VERSION)
    parser.add_argument('--key', help="key file or PKCS#11 URL", required=True)
    parser.add_argument('--skip-latest', help="skip updating the 'latest' references", action='store_true')
    parser.add_argument('--override-cert', help="use a previous cert when switching PKI pairs")
    parser.add_argument('--dry-run', help="prepares artifacts, but only prints what would normally be uploaded", action='store_true')
    parser.add_argument('--verbose', help="list all artifacts in the built version", action='store_true')

    _main(parser.parse_args())
