#!/usr/bin/env python

import argparse
import subprocess

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


def _main(opts):
    subprocess.run([
        RAUC, "--key", opts.key, "--cert", opts.cert, "--keyring", KEYRING,
        "resign", UNSIGNED_RAUC_BUNDLE, "playos-" + VERSION + ".raucb"
    ])
    exit(0)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Deploy PlayOS update")
    parser.add_argument('-v', '--version', action='version', version=VERSION)
    parser.add_argument('--key', help="key file or PKCS#11 URL", required=True)
    parser.add_argument(
        '--cert', help="cert file or PKCS#11 URL", default=KEYRING)
    _main(parser.parse_args())
