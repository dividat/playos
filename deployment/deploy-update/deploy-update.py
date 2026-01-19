#!@python3@/bin/python

import argparse
from dataclasses import dataclass
import hashlib
import subprocess
import os
import os.path
import tempfile
import textwrap
import sys
import urllib.request as request

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
class VersionItem:
    """An item to be added to a version on the dist host."""
    human_name: str
    file_name: str
    local_path: str
    include_in_summary: bool

    @property
    def url(self) -> str:
        return UPDATE_URL + VERSION + "/" + self.file_name

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

    print(f"Deploying {FULL_PRODUCT_NAME} {VERSION}:\n")

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

        if not _query_continue("\nContinue?"):
            print("Aborted.")
            exit(1)


        # Gather items to deploy for this version
        bundle = VersionItem(
            human_name = "RAUC Bundle",
            file_name = f"{SAFE_PRODUCT_NAME}-{VERSION}.raucb",
            local_path = signed_bundle_path,
            include_in_summary = False
        )
        manual = VersionItem(
            human_name = "Manual",
            file_name = f"{SAFE_PRODUCT_NAME}-manual-{VERSION}.pdf",
            local_path = os.path.join(DOCS, "user-manual.pdf"),
            include_in_summary = True
        )
        version_items = [ bundle, manual ]

        if INSTALLER_ISO:
            installer_iso_filename = f"{SAFE_PRODUCT_NAME}-installer-{VERSION}.iso"
            version_items.append(VersionItem(
                human_name = "Installer",
                file_name = installer_iso_filename,
                local_path = os.path.join(INSTALLER_ISO, "iso", installer_iso_filename),
                include_in_summary = True
            ))

        if LIVE_ISO:
            live_iso_filename = f"{SAFE_PRODUCT_NAME}-live-{VERSION}.iso"
            version_items.append(VersionItem(
                human_name = "Live System",
                file_name = live_iso_filename,
                local_path = os.path.join(LIVE_ISO, "iso", live_iso_filename),
                include_in_summary = False
            ))


        # Deploy the version
        for item in version_items:
            subprocess.run(
                [
                    AWS_CLI, "s3", "cp", item.local_path, DEPLOY_URL + VERSION + "/" + item.file_name,
                    "--acl", "public-read"
                ],
                check=True)

        if not opts.skip_latest:
            # Deploy the latest file
            latest_file = os.path.join(release_tmp_dir, "latest")
            with open(latest_file, 'w') as latest:
                latest.write(VERSION + "\n")
            subprocess.run(
                [
                    AWS_CLI,
                    "s3",
                    "cp",
                    latest_file,
                    DEPLOY_URL + "latest",
                    "--acl",
                    "public-read",
                    "--cache-control",
                    "max-age=0"
                ],
                check=True)

            # Create copy of latest manual at fixed name
            subprocess.run(
                [
                    AWS_CLI,
                    "s3",
                    "cp",
                    # We have to re-upload this file; copying within bucket is faster, but does not allow setting headers
                    manual.local_path,
                    DEPLOY_URL + "manual-latest.pdf",
                    "--acl",
                    "public-read",
                    "--cache-control",
                    "max-age=0",
                    "--content-disposition",
                    "attachment; filename=\"%s\"" % manual.file_name
                ],
                check=True)

        print()
        print("CHECKS")
        print("======\n")
        verify(
            f"Latest version has been updated",
            lambda: request.urlopen(f"{UPDATE_URL}/latest", timeout=5).read().decode().strip(),
            VERSION,
            skip=opts.skip_latest)
        verify(
            f"Bundle is accessible",
            lambda: request.urlopen(request.Request(f"{UPDATE_URL}/{VERSION}/{bundle.file_name}", method="HEAD"), timeout=5).status,
            200)

        summary = "\n".join(
            item.summarize()
            for item in version_items
            if item.include_in_summary
        )
        print()
        print("DEPLOYMENT SUMMARY")
        print("==================")
        print(summary)


        exit(0)

def verify(description, check, expected, skip=False):
    if skip:
        print(f"SKIP [{description}]")
        return

    try:
        actual = check()
        if actual == expected:
            print(f"\033[92mOK\033[0m [{description}]")
        else:
            print(f"\033[91mFAIL\033[0m [{description}] Expected {expected}, got {actual}")
    except Exception as e:
        print(f"\033[91mFAIL\033[0m [{description}] Exception: {e}")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=f"Deploy {FULL_PRODUCT_NAME} update")
    parser.add_argument('-v', '--version', action='version', version=VERSION)
    parser.add_argument('--key', help="key file or PKCS#11 URL", required=True)
    parser.add_argument('--skip-latest', help="skip updating the 'latest' references", action='store_true')
    parser.add_argument('--override-cert', help="use a previous cert when switching PKI pairs")
    _main(parser.parse_args())
