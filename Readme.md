# PlayOS

PlayOS is a Linux system to act as an application kiosk. PlayOS is a layer on top of [NixOS](https://nixos.org/).

The base layer functionality of PlayOS is:

- Automatic A/B update mechanism
- Read-only system partitions, with selected persisted configuration data
- Web-based configuration interface for
  - network (LAN, WLAN, HTTP proxy, static IP),
  - localization,
  - system status,
  - remote maintenance.
- Installer
- Live system
- Remote maintenance via ZeroTier

The application layer may be defined in a single Nix file.

This repository contains the application layer for running the Dividat Play web app and supporting system services in a fullscreen kiosk.

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

## Testing

### Virtual machine

Most changes to system configuration and/or the contoller can be tested in a virtual machine.
To create and run a VM, run:

```bash
./build vm
./result/bin/run-in-vm
```

In order to get the vm system journal, look at the output of `run-in-vm`
for a command starting with `socat`.

See the output of `./result/bin/run-in-vm --help` for more information.

#### Guest networking

The default user-mode network stack is used to create a virtual Ethernet connection with bridged Internet access for the guest. If you find that the guest has a dysfunctional Internet connection, check your host's firewall settings. If using ConnMan, restart ConnMan service and try again.

### Testing on PlayOS hardware

Changes such as NixOS upgrades, or to anything else that directly interacts with system hardware may necessitate testing on an actual machine. To do so, build a live system:

```bash
nix-build --arg buildInstaller false --arg buildBundle false --arg buildDisk false
```

Flash the iso in `./result/` to a USB stick and boot from this stick on the PlayOS computer.
Building a complete system like this is a lengthy process, so it is a good idea to test at the component level (controller, kiosk) first, where possible. 

### Controller testing

When making changes to the controller, it's possible to run and test it directly on your machine, without a VM or a live system. See the Controller's [Readme](controller/Readme.md) for details.


### Automated Testing

Subcomponent tests using the [NixOS test framework](https://nixos.org/manual/nixos/stable/index.html#sec-nixos-tests) may be added to `test/integration`.

Run tests with

    testing/run

or individual tests with

    nix-build testing/integration/EXAMPLE.nix

Tests added to `test/integration` are executed via a GitHub Action when pushing or creating pull requests.

## Deployment

Update bundles are hosted on Amazon S3. The script `bin/deploy-update` will handle signing and uploading of bundle.

The arguments `updateUrl` (from where updates will be fetched by PlayOS systems), `deployURL` (where bundles should be deployed to) must be specified. For example: `nix build --arg updateUrl https://dist.dividat.com/releases/playos/master/ --arg deployUrl s3://dist.dividat.ch/releases/playos/master/`.

Commonly used update and deploy URLs (channels) can be used with shortcuts defined in `./build`.

To release an update to the `develop` channel:

```
./build develop
./result/bin/deploy-update --key PATH_TO_KEY.pem
```

### Key switch

When switching key pairs on a channel, the new certficiate must be built into the bundle, which must then be signed with the old key. For this purpose, the `--override-cert` option of the deploy script is needed to provide RAUC with a certificate matching the new key.

## Change Log

Update the change log for every release. See http://keepachangelog.com/ for formatting and conventions.

## Dev tools

The following [dev tools](dev-tools/Readme.md) are available:

- Simulate a captive portal

## Related work

- [Yocto](https://www.yoctoproject.org/): A builder for embedded Linux distributions. Widely used but not very well suited for desktop functionality (such as browser).
- [Buildroot](https://buildroot.org/): Builder for embedded Linux systems. Also not very well suited for desktop functionality.
- [not-os](https://github.com/cleverca22/not-os): A NixOS based system generator. Much more minimal than NixOS, does not use systemd and is not compatible with existing NixOS modules.

## Attribution and Licensing

Most code in this repository is authored by the Dividat AG and the project contributors. This code is licensed under an MIT license.

Some source files in this project are portions of other open-source project and may be released under different licenses. The applicable licenses are stated here as well as in the relevant subdirectories.

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
