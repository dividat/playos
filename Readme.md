# PlayOS

A custom Linux system ([NixOS](https://nixos.org/)) for running Dividat Play.

See the [documentation](docs/arch) for more information.

## Quick start

Running `nix build` will create following (in `result/`):

- `system/`: System toplevel
- `testing/`: System toplevel with test instrumentation
- `bin/`: Tools
- `playos-VERSION.raucb`: RAUC bundle that can be used to update systems. Note that it is signed with a dummy development key. Real deployments would resign the bundle with `rauc resign`.
- `playos-installer-VERSION.iso`: Bootable ISO image that can install the system.
- `disk.img`: Preinstalled disk with bootloader, system partitions A/B and data partitions for testing (but without test instrumentation).

For quicker development cycles you may pass following arguments to the build:

- `buildInstaller`: Should the installer ISO image be built.
- `buildBundle`: Should the RAUC bundle be built.
- `buildDisk`: Should the preinstalled disk image.

For example: `nix build --arg buildInstaller false --arg buildBundle false` will only build the system toplevels and the preinstalled disk image.

A virtual machine (with test instrumentation) can be started without any of the above builds.

### Virtual machine

A helper is available to quickly start a virtual machine:


```
nix build && ./result/bin/run-playos-in-vm
```


See the output of `run-playos-in-vm --help` for more information.


## Related work

- [Yocto](https://www.yoctoproject.org/): A builder for embedded Linux distributions. Widely used but not very well suited for desktop functionality (such as browser).
- [Buildroot](https://buildroot.org/): Builder for embedded Linux systems. Also not very well suited for desktop functionality.
- [not-os](https://github.com/cleverca22/not-os): A NixOS based system generator. Much more minimal than NixOS, does not use systemd and is not compatible with existing NixOS modules.
