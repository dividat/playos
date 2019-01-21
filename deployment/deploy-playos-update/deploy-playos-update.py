#!@python36@/bin/python

import argparse
import subprocess
import os.path

KEYRING = "@keyring@"
UNSIGNED_RAUC_BUNDLE = "@unsignedRaucBundle@"
VERSION = "@version@"

RAUC = "@rauc@/bin/rauc"


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


def sign_rauc_bundle(key, cert, keyring, out):
    subprocess.run([
        RAUC, "--key", key, "--cert", cert, "--keyring", keyring, "resign",
        UNSIGNED_RAUC_BUNDLE, out
    ])


def _main(opts):
    # Create the output directory
    os.makedirs(opts.out, exist_ok=True)

    # Create the version directory
    os.makedirs(os.path.join(opts.out, VERSION), exist_ok=True)

    # Sign RAUC bundle
    sign_rauc_bundle(
        key=opts.key,
        cert=opts.cert,
        keyring=KEYRING,
        out=os.path.join(opts.out, VERSION, "playos-" + VERSION + ".raucb"))

    # Write latest file
    with open(os.path.join(opts.out, 'latest'), 'w') as latest:
        latest.write(VERSION + "\n")

    exit(0)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Deploy PlayOS update")
    parser.add_argument('-v', '--version', action='version', version=VERSION)
    parser.add_argument('--key', help="key file or PKCS#11 URL", required=True)
    parser.add_argument(
        '--out',
        help="directory to output release files to",
        default='./release')
    parser.add_argument(
        '--cert', help="cert file or PKCS#11 URL", default=KEYRING)
    _main(parser.parse_args())
