# PlayOS

A custom Linux system ([NixOS](https://nixos.org/)) for running Dividat Play.

See the [documentation](docs/arch) for more information.

## Quick start

Running `nix build` will create following (in `result/`):

- `bin/`: Tools
- `playos-VERSION-UNSIGNED.raucb`: RAUC bundle that can be used to update systems. Note that it is signed with a dummy development key. Real deployments would resign the bundle with `rauc resign`.
- `playos-installer-VERSION.iso`: Bootable ISO image that can install the system.
- `disk.img`: Preinstalled disk with bootloader, system partitions A/B and data partitions for testing (but without test instrumentation).

### Choose what to build

For quicker development cycles you may pass following arguments to the build:

- `buildInstaller`: Should the installer ISO image be built.
- `buildBundle`: Should the RAUC bundle be built.
- `buildDisk`: Should the preinstalled disk image be built.
- `buildLive`: Should the PlayOS live system image be built.

For example: `nix build --arg buildInstaller false --arg buildBundle false` will only build the system toplevels and the preinstalled disk image.

A virtual machine (with test instrumentation) can be started without any of the above builds.

### Virtual machine

A helper is available to quickly start a virtual machine:

```
make vm && ./result/bin/run-playos-in-vm
```

See the output of `run-playos-in-vm --help` for more information.

## Deployment

Update bundles are hosted on Amazon S3. The script `bin/deploy-playos-update` will handle signing and uploading of bundle.

The arguments `updateUrl` (from where updates will be fetched by PlayOS systems), `deployURL` (where bundles should be deployed to) must be specified. For example: `nix build --arg updateUrl https://dist.dividat.com/releases/playos/master/ --arg deployUrl s3://dist.dividat.ch/releases/playos/master/`.

Commonly used update and deploy URLs (channels) can be used with shortcuts defined in the Makefile.

To release an update to the `develop` channel:

```
make develop
./result/bin/deploy-playos-update --key PATH_TO_KEY.pem
```

### Key switch

When switching key pairs on a channel, the new certficiate must be built into the bundle, which must then be signed with the old key. For this purpose, the `--override-cert` option of the deploy script is needed to provide RAUC with a certificate matching the new key.

## Installation on VirtualBox

1. Use `nix-build`. At least `buildInstaller` must be enabled. See
   https://github.com/dividat/playos/tree/develop#choose-what-to-build.

2. On VirtualBox, create a new virtual machine with:

- RAM: 4096MB,
- Virtual VDI HDD: 60GB dynamically allocated.

Update the following settings:

- `Settings > Display > Graphics controller:` set `VBoxSVGA` (see [this issue](https://discourse.nixos.org/t/trying-to-fix-very-poor-virtualbox-install-experience/2488), but it [should be resolved on NixOS 20.03](https://github.com/NixOS/nixpkgs/commit/58d0134da072548eb66d9313ad629e4dffddfd9d)),
- `Settings > System > Motherboard`: enable EFI.

3. Install PlayOS from `result/playos-installer-VERSION.iso` to the virtual
   machine. Don’t forget to remove the optical drive in `Settings > Storage`
   once the installation has been completed.

## Change Log

Update the change log for every release. See http://keepachangelog.com/ for formatting and conventions.

## Related work

- [Yocto](https://www.yoctoproject.org/): A builder for embedded Linux distributions. Widely used but not very well suited for desktop functionality (such as browser).
- [Buildroot](https://buildroot.org/): Builder for embedded Linux systems. Also not very well suited for desktop functionality.
- [not-os](https://github.com/cleverca22/not-os): A NixOS based system generator. Much more minimal than NixOS, does not use systemd and is not compatible with existing NixOS modules.

## Attribution

This software contains portions from other open-source projects.

### [nixpkgs](https://github.com/NixOS/nixpkgs)

```
Copyright (c) 2003-2018 Eelco Dolstra and the Nixpkgs/NixOS contributors

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

### [Feather](https://feathericons.com/)

```
The MIT License (MIT)

Copyright (c) 2013-2017 Cole Bemis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
