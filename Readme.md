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

See the [documentation](docs/arch) and [user manual](docs/user-manual) for more information.

## Building the system

### Quick start

The quickest way to see the system in action is to [use the QEMU VM](#qemu-vm).

You can perform all common build variants using the `build` script. Run `./build` without parameters for a list of build variants.

### Full build

Running `./build all` (equivalently `nix-build`) creates all of the following (in `result/`):

- `bin/`: Tools
- `playos-VERSION-UNSIGNED.raucb`: RAUC bundle that can be used to update systems. Note that it is signed with a dummy development key. Real deployments would resign the bundle with `rauc resign`.
- `playos-installer-VERSION.iso`: Bootable ISO image that can install the system.
- `disk.img`: Preinstalled disk with bootloader, system partitions A/B and data partitions for testing (but without test instrumentation).

Note that a full build takes a long time.

### Choose what to build

The following arguments may be used to control the build outputs:

- `buildInstaller`: Should the installer ISO image be built.
- `buildBundle`: Should the RAUC bundle be built.
- `buildDisk`: Should the preinstalled disk image be built.
- `buildLive`: Should the PlayOS live system image be built.

For example: `nix build --arg buildInstaller false --arg buildBundle false` will only build the system toplevels and the preinstalled disk image.

You can pass set the env variable `QUICK_BUILD=1` or append `--arg quickBuild true` to the nix-build argument list for a faster development build (lower compression).


## System Testing

To test integrated portions of the PlayOS system, there are several options/levels available:

- Running a single system partition with QEMU (fast, partial, isolated)
- Running a full system inside a virtual machine such as VirtualBox (slow, simulated full, isolated)
- Running a single system partition from a USB stick on a physical machine (medium fast, partial, isolated)
- Running a full system on a physical machine (slow, full, isolated)

### QEMU VM

Most changes to system configuration and/or the controller can be tested in a virtual machine.
To create and run a VM, run:

```bash
./build vm
./result/bin/run-in-vm
```

In order to get the vm system journal, look at the output of `run-in-vm`
for a command starting with `socat`.

See the output of `./result/bin/run-in-vm --help` for more information.

#### Guest networking

The default user-mode network stack is used to create a virtual Ethernet connection with bridged Internet access for the guest. If you find that the guest has a dysfunctional Internet connection, check your host's firewall settings. If using ConnMan on the host, restart the ConnMan service and try again.

### VirtualBox VM

PlayOS can also be tested on a VM like VirtualBox, which can simulate a system more fully, including the installer, Grub and A/B partitions. Guidance for setting this up can be found [here](./docs/arch/Readme.org#installation-on-virtualbox).

### Testing on PlayOS hardware

Changes such as NixOS upgrades, or to anything else that directly interacts with system hardware may necessitate testing on physical hardware. This can be done by booting from a live system or performing a complete installation.

To build only a live system:

```bash
nix-build --arg buildInstaller false --arg buildBundle false --arg buildDisk false
```

To build only an installer:

```bash
nix-build --arg buildLive false --arg buildBundle false --arg buildDisk false
```

Flash the ISO in `./result/` to a USB stick and boot or install PlayOS.

Building a complete system takes time, so it is a good idea to test at the component or QEMU VM level first, where possible.

### Automated Testing

There are 4 types of automated tests:

- unit tests (used in kiosk and controller)
- subcomponent integration tests
- end-to-end system level tests
- release validation tests

All but the last are run on each commit via Github Actions.

See subsections below for more details on each test type.


#### Subcomponent (integration) tests

Subcomponent tests using the [NixOS test framework](https://nixos.org/manual/nixos/stable/index.html#sec-nixos-tests) may be added to `testing/integration`.

Run tests with

    testing/run

or individual tests with

    nix-build testing/integration/EXAMPLE.nix

Tests added to `test/integration` are executed via a GitHub Action when pushing or creating pull requests.

#### End-to-end system tests

End-to-end tests use the full PlayOS system, ran on a VM from an installed disk image (obtained from `buildDisk`).

**Note**: the system-under-test will have some extra modules and services installed that are needed for test instrumentation and therefore is not 100% identical to the "real" PlayOS system, see [testing/end-to-end/profile.nix](testing/end-to-end/profile.nix) for the modifications.

To run the tests, execute

    ./build test-e2e

This will first build the interactive test runners for each test (useful for
debugging) and put them in
`./result/tests/interactive/<TEST_NAME>/bin/nixos-test-driver`). Afterwards, it
will run a second `nix-build` that will run all of the tests.

To add additional tests, follow the examples in
[testing/end-to-end/tests/](testing/end-to-end/tests/).

*Note*: if running non-NixOS Linux, ensure you have KVM setup and `/dev/kvm` is
*world read-writable* (if not, do `chmod o+rw /dev/kvm`), otherwise qemu invoked
by `nixbld` users will not able to utilize KVM acceleration and everything will
run 10x slower. If you see `failed to initialize KVM` in the console logs, it
means there's a problem. See [this (outdated) Github issue](https://github.com/NixOS/nixpkgs/issues/124371#issue-900719073)
for more details.


#### Release validation (self-update) test

The release validation test is used to perform the final _automated_ checks before
manually testing and officially publishing a release.

Currently it tests only one critical path: the self-update scenario from an
earlier release (the 'base' system) to the current/upcoming release (the 'next'
system).

The test does not alter the configuration of the base or next systems' in any way
(e.g. no test-instrumentation.nix extras, which are present in end-to-end
tests).

To run the tests against the previous release, execute:

    nix-build testing/release-validation.nix

To test against a specific base system (e.g. `2023.9.1-DISK`), add the flag
`--arg baseSystemVersion '"2023.9.1-DISK"'`.

Compressed base system disk images are created for every tagged release using
`./build release-disk` and the [release](.github/workflows/release-tag.yml)
Github workflow. See the "Test disk" links in [release
summaries](https://github.com/dividat/playos/releases).

For more details, see the comments in
[testing/release-validation.nix](testing/release-validation.nix).

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

## Components

### Controller

The [controller](controller/) service orchestrates the system's self-update and acts as a configuration interface for the options exposed to the user. It may be run directly on a Linux host for development purposes.

### Kiosk

The [kiosk](kiosk/) browser is used in the default configuration of PlayOS to run any web application in a full screen kiosk. It can be run directly on most hosts for development purposes.

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

Most code in this repository is authored by the Dividat AG and the project
contributors. This code is licensed under [the MIT license](./LICENSE).

Some source files in this project are portions of other open-source project and
may be released under different licenses. The applicable licenses are stated
here as well as in the relevant subdirectories.

- [nixpkgs](https://github.com/NixOS/nixpkgs) ([MIT License](./controller/licenses/NIXPKGS))
- [Feather](https://feathericons.com/) ([MIT License](./controller/licenses/FEATHER)) – used in the [controller](./controller/Readme.md)
- [Qt6](https://www.qt.io/product/qt6) ([LGPLv3 License](./controller/licenses/QT6)) – used in the [kiosk](./kiosk/Readme.md)
