#!@python36@/bin/python

import argparse
import subprocess
import os
import os.path
import tempfile
import sys

UNSIGNED_RAUC_BUNDLE = "@unsignedRaucBundle@"
INSTALLER_ISO = "@installer@"
VERSION = "@version@"

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


def sign_rauc_bundle(key, cert, out):
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

    print("Deploying PlayOS update:\n")

    output_cert = UPDATE_CERT if opts.override_cert == None else opts.override_cert

    with tempfile.TemporaryDirectory(
            prefix="playos-signed-release", dir=TMPDIR) as signed_release:

        # Create the version directory
        version_dir = os.path.join(signed_release, VERSION)
        os.makedirs(version_dir, exist_ok=True)

        # Sign RAUC bundle (and verify signature)
        signed_bundle = os.path.join(version_dir,
                                     "playos-" + VERSION + ".raucb")
        sign_rauc_bundle(key=opts.key, cert=output_cert, out=signed_bundle)

        # Write latest file
        latest_file = os.path.join(signed_release, "latest")
        with open(latest_file, 'w') as latest:
            latest.write(VERSION + "\n")

        installer_iso_filename = "playos-installer-" + VERSION + ".iso"
        installer_iso_src = os.path.join(INSTALLER_ISO, "iso", installer_iso_filename)
        installer_iso_dst = os.path.join(version_dir, installer_iso_filename)
        subprocess.run(["cp", installer_iso_src, installer_iso_dst],
            check=True)

        # Print some information and wait for confirmation
        print("Update URL:\t%s" % UPDATE_URL)
        print("Deploy URL:\t%s" % DEPLOY_URL)
        print("Kiosk URL:\t%s" % KIOSK_URL)

        # Show RAUC info
        subprocess.run(
            [RAUC, "info", "--keyring", output_cert, signed_bundle],
            stderr=subprocess.DEVNULL,
            check=True)

        if not _query_continue("\nContinue?"):
            print("Aborted.")
            exit(1)

        # TODO: use boto3 library instead of calling awscli
        # Deploy the version
        subprocess.run(
            [
                AWS_CLI, "s3", "cp", version_dir, DEPLOY_URL + VERSION + "/",
                "--recursive", "--acl", "public-read"
            ],
            check=True)

        # Deploy the latest file
        subprocess.run(
            [
                AWS_CLI,
                "s3",
                "cp",
                latest_file,
                DEPLOY_URL + "latest",
                "--acl",
                "public-read",
                # TODO: increase this once out of testing to increase CDN cache hits
                "--cache-control",
                "max-age=0"
            ],
            check=True)

        print("Deployment completed.")

        exit(0)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Deploy PlayOS update")
    parser.add_argument('-v', '--version', action='version', version=VERSION)
    parser.add_argument('--key', help="key file or PKCS#11 URL", required=True)
    parser.add_argument('--override-cert', help="use a previous cert when switching PKI pairs")
    _main(parser.parse_args())
